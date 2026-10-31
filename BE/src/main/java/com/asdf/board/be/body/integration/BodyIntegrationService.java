package com.asdf.board.be.body.integration;

import com.asdf.board.be.body.entity.*;
import com.asdf.board.be.global.exception.*;
import com.asdf.board.be.user.entity.*;
import com.asdf.board.be.user.repository.*;
import java.math.*;
import java.net.URI;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.MessageDigest;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import javax.imageio.ImageIO;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.multipart.MultipartFile;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

@Service
@Slf4j
public class BodyIntegrationService {
  private final PhotoRepository photos;
  private final AnalysisRepository analyses;
  private final UserRepository users;
  private final UserProfileRepository profiles;
  private final UserConsentRepository consents;
  private final ObjectMapper json;
  private final TransactionTemplate tx;
  private final ExecutorService executor;
  private final Path storage;
  private final String aiUrl, publicUrl, secret;
  private final HttpClient http =
      HttpClient.newBuilder()
          .version(HttpClient.Version.HTTP_1_1)
          .connectTimeout(Duration.ofSeconds(5))
          .build();
  private final ZoneId zone = ZoneId.of("Asia/Seoul");

  public BodyIntegrationService(
      PhotoRepository p,
      AnalysisRepository a,
      UserRepository u,
      UserProfileRepository pr,
      UserConsentRepository c,
      ObjectMapper j,
      PlatformTransactionManager tm,
      ExecutorService ex,
      @Value("${vitality.storage-dir:./data/photos}") String dir,
      @Value("${vitality.ai-url:http://127.0.0.1:8001}") String ai,
      @Value("${vitality.public-url:http://127.0.0.1:8080}") String pub,
      @Value("${vitality.jwt.secret}") String key)
      throws Exception {
    photos = p;
    analyses = a;
    users = u;
    profiles = pr;
    consents = c;
    json = j;
    tx = new TransactionTemplate(tm);
    executor = ex;
    storage = Path.of(dir).toAbsolutePath().normalize();
    Files.createDirectories(storage);
    aiUrl = ai;
    publicUrl = pub.replaceAll("/$", "");
    secret = key;
  }

  private LocalDateTime now() {
    return LocalDateTime.now(zone);
  }

  private String timestamp(LocalDateTime date) {
    return date == null ? null : date.atZone(zone).toOffsetDateTime().toString();
  }

  public static Map<String, Object> obj(Object... pairs) {
    Map<String, Object> m = new LinkedHashMap<>();
    for (int i = 0; i < pairs.length; i += 2) m.put((String) pairs[i], pairs[i + 1]);
    return m;
  }

  private void fail(ErrorCode c) {
    throw new ApiException(c);
  }

  private User access(long userId, boolean ai) {
    User user = users.findById(userId).orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
    if (user.getStatus() != User.Status.active) fail(ErrorCode.UNAUTHORIZED);
    if (!profiles.existsByUserId(userId)) fail(ErrorCode.ONBOARDING_REQUIRED);
    Map<UserConsent.ConsentType, Boolean> current = new EnumMap<>(UserConsent.ConsentType.class);
    consents
        .findByUserIdOrderByIdAsc(userId)
        .forEach(c -> current.put(c.getConsentType(), c.getAgreed()));
    if (!Boolean.TRUE.equals(current.get(UserConsent.ConsentType.body_photo))
        || (ai && !Boolean.TRUE.equals(current.get(UserConsent.ConsentType.ai_processing))))
      fail(ErrorCode.CONSENT_REQUIRED);
    return user;
  }

  private Photo ownedPhoto(long userId, long id) {
    Photo p = photos.findById(id).orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
    if (p.getDeletedAt() != null || !p.getUser().getId().equals(userId)) fail(ErrorCode.NOT_FOUND);
    return p;
  }

  private Path path(Photo p) {
    Path target = storage.resolve(p.getStorageKey()).normalize();
    if (!target.startsWith(storage)) throw new IllegalStateException();
    return target;
  }

  private String signature(long id, long exp) {
    try {
      Mac mac = Mac.getInstance("HmacSHA256");
      mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
      return HexFormat.of()
          .formatHex(mac.doFinal((id + ":" + exp).getBytes(StandardCharsets.UTF_8)));
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  private Map<String, Object> photoView(Photo p) {
    long exp = Instant.now().plusSeconds(3600).getEpochSecond();
    return obj(
        "photo_id",
        p.getId(),
        "type",
        p.getType().name(),
        "side",
        p.getSide().name(),
        "url",
        publicUrl
            + "/api/photo-files/"
            + p.getId()
            + "?expires="
            + exp
            + "&signature="
            + signature(p.getId(), exp),
        "url_expires_at",
        Instant.ofEpochSecond(exp).toString(),
        "created_at",
        timestamp(p.getCreatedAt()));
  }

  public synchronized Map<String, Object> upload(
      long uid, MultipartFile file, String type, String side) throws Exception {
    tx.executeWithoutResult(t -> access(uid, false));
    if (file.isEmpty() || file.getSize() > 10 * 1024 * 1024) fail(ErrorCode.VALIDATION_FAILED);
    Photo.Type kind;
    Photo.Side direction;
    try {
      kind = Photo.Type.valueOf(type);
      direction = Photo.Side.valueOf(side);
    } catch (Exception e) {
      throw new ApiException(ErrorCode.VALIDATION_FAILED);
    }
    byte[] bytes = file.getBytes();
    boolean jpg =
        bytes.length > 3
            && (bytes[0] & 255) == 255
            && (bytes[1] & 255) == 216
            && (bytes[2] & 255) == 255;
    boolean png =
        bytes.length > 8
            && Arrays.equals(
                Arrays.copyOf(bytes, 8), new byte[] {(byte) 137, 80, 78, 71, 13, 10, 26, 10});
    if (!jpg && !png) fail(ErrorCode.VALIDATION_FAILED);
    // Decode before accepting corrupted images; compressed pixel bomb bounded separately in AI.
    try (var stream = ImageIO.createImageInputStream(new java.io.ByteArrayInputStream(bytes))) {
      var readers = ImageIO.getImageReaders(stream);
      if (!readers.hasNext()) fail(ErrorCode.VALIDATION_FAILED);
      var reader = readers.next();
      try {
        reader.setInput(stream);
        if ((long) reader.getWidth(0) * reader.getHeight(0) > 25_000_000)
          fail(ErrorCode.VALIDATION_FAILED);
      } finally {
        reader.dispose();
      }
    } catch (java.io.IOException e) {
      throw new ApiException(ErrorCode.VALIDATION_FAILED);
    }
    String key = UUID.randomUUID() + (jpg ? ".jpg" : ".png");
    Path target = storage.resolve(key);
    try {
      return tx.execute(
          status -> {
            User user = access(uid, false);
            if (photos.findByUserIdAndDeletedAtIsNullOrderByIdDesc(uid).size() >= 20)
              fail(ErrorCode.PHOTO_LIMIT_EXCEEDED);
            try {
              Files.write(target, bytes);
            } catch (Exception e) {
              throw new IllegalStateException(e);
            }
            Photo p =
                photos.saveAndFlush(
                    Photo.builder()
                        .user(user)
                        .type(kind)
                        .side(direction)
                        .storageKey(key)
                        .contentType(jpg ? "image/jpeg" : "image/png")
                        .sizeBytes(bytes.length)
                        .build());
            return photoView(p);
          });
    } catch (Exception e) {
      Files.deleteIfExists(target);
      throw e;
    }
  }

  public Map<String, Object> listPhotos(long uid, String type) {
    return tx.execute(
        t -> {
          access(uid, false);
          var list =
              photos.findByUserIdAndDeletedAtIsNullOrderByIdDesc(uid).stream()
                  .filter(p -> p.getType().name().equals(type))
                  .map(this::photoView)
                  .toList();
          return obj("items", list, "total", list.size(), "page", 1);
        });
  }

  public record PhotoFile(byte[] bytes, String contentType) {}

  public PhotoFile file(long id, long exp, String sig) {
    return tx.execute(
        t -> {
          if (exp < Instant.now().getEpochSecond()
              || !MessageDigest.isEqual(
                  signature(id, exp).getBytes(StandardCharsets.UTF_8),
                  sig.getBytes(StandardCharsets.UTF_8))) fail(ErrorCode.NOT_FOUND);
          Photo p = photos.findById(id).orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
          if (p.getDeletedAt() != null || p.getUser().getStatus() != User.Status.active)
            fail(ErrorCode.NOT_FOUND);
          try {
            return new PhotoFile(Files.readAllBytes(path(p)), p.getContentType());
          } catch (Exception e) {
            throw new ApiException(ErrorCode.NOT_FOUND);
          }
        });
  }

  public synchronized Map<String, Object> deletePhotos(long uid, Long id, String type) {
    return tx.execute(
        t -> {
          access(uid, false);
          var list =
              id == null
                  ? photos.findByUserIdAndDeletedAtIsNullOrderByIdDesc(uid).stream()
                      .filter(p -> p.getType().name().equals(type))
                      .toList()
                  : List.of(ownedPhoto(uid, id));
          int deleted = 0, skipped = 0;
          for (Photo p : list) {
            if (analyses.findByUserIdOrderByIdDesc(uid).stream()
                .anyMatch(
                    a ->
                        a.getStatus() == BodyAnalysis.Status.pending
                            && ((a.getPhoto() != null && a.getPhoto().getId().equals(p.getId()))
                                || (a.getSidePhoto() != null
                                    && a.getSidePhoto().getId().equals(p.getId()))))) {
              skipped++;
              continue;
            }
            try {
              Files.deleteIfExists(path(p));
            } catch (Exception e) {
              throw new IllegalStateException(e);
            }
            p.setDeletedAt(now());
            photos.save(p);
            deleted++;
          }
          return obj("deleted_count", deleted, "skipped_count", skipped);
        });
  }

  public Map<String, Object> usage(long uid) {
    return tx.execute(
        t -> {
          User currentUser = access(uid, true);
          boolean unlimited = currentUser.getRole() == User.Role.admin;
          long used =
              analyses.findByUserIdOrderByIdDesc(uid).stream()
                  .filter(
                      a ->
                          !a.getCreatedAt().toLocalDate().isBefore(now().toLocalDate())
                              && a.getStatus() != BodyAnalysis.Status.failed)
                  .count();
          return obj(
              "used",
              used,
              "limit",
              unlimited ? 0 : 3,
              "remaining",
              unlimited ? 0 : Math.max(0, 3 - used),
              "unlimited",
              unlimited,
              "reset_at",
              timestamp(now().toLocalDate().plusDays(1).atStartOfDay()));
        });
  }

  public synchronized Map<String, Object> start(long uid, long photoId, Long sideId, Long goalId) {
    if (goalId != null) fail(ErrorCode.GOAL_NOT_READY);
    var ticket =
        tx.execute(
            t -> {
              User user = access(uid, true);
              var prior = analyses.findByUserIdOrderByIdDesc(uid);
              if (prior.stream().anyMatch(a -> a.getStatus() == BodyAnalysis.Status.pending))
                fail(ErrorCode.ANALYSIS_IN_PROGRESS);
              Photo p = ownedPhoto(uid, photoId);
              if (p.getType() != Photo.Type.current || p.getSide() != Photo.Side.front)
                fail(ErrorCode.PHOTO_TYPE_MISMATCH);
              Photo side = sideId == null ? null : ownedPhoto(uid, sideId);
              if (side != null
                  && (side.getType() != Photo.Type.current || side.getSide() != Photo.Side.side))
                fail(ErrorCode.PHOTO_TYPE_MISMATCH);
              // Reuse the same photo's completed result without spending another quota slot.
              var cached =
                  prior.stream()
                      .filter(
                          a ->
                              a.getStatus() == BodyAnalysis.Status.done
                                  && a.getPhoto() != null
                                  && a.getPhoto().getId().equals(photoId)
                                  && Objects.equals(
                                      a.getSidePhoto() == null ? null : a.getSidePhoto().getId(),
                                      sideId))
                      .findFirst();
              if (cached.isPresent())
                return obj(
                    "analysis_id",
                    cached.get().getId(),
                    "status",
                    "done",
                    "created_at",
                    timestamp(cached.get().getCreatedAt()),
                    "poll_after_ms",
                    2000);
              if (user.getRole() != User.Role.admin
                  && ((Number) usage(uid).get("remaining")).intValue() == 0)
                fail(ErrorCode.ANALYSIS_QUOTA_EXCEEDED);
              BodyAnalysis a =
                  analyses.saveAndFlush(
                      BodyAnalysis.builder().user(user).photo(p).sidePhoto(side).build());
              return obj(
                  "analysis_id",
                  a.getId(),
                  "status",
                  "pending",
                  "created_at",
                  timestamp(a.getCreatedAt()),
                  "poll_after_ms",
                  2000);
            });
    if ("pending".equals(ticket.get("status"))) {
      long id = ((Number) ticket.get("analysis_id")).longValue();
      try {
        executor.submit(() -> process(id));
      } catch (RejectedExecutionException ex) {
        finishFailure(id, "AI_FAILED", "분석 서버가 사용 중입니다. 다시 시도해 주세요.");
      }
    }
    return ticket;
  }

  private void process(long id) {
    try {
      byte[] image =
          tx.execute(
              t -> {
                var a = analyses.findById(id).orElseThrow();
                if (a.getStatus() != BodyAnalysis.Status.pending
                    || a.getCreatedAt().isBefore(now().minusSeconds(90))) return null;
                try {
                  return Files.readAllBytes(path(a.getPhoto()));
                } catch (Exception e) {
                  throw new IllegalStateException(e);
                }
              });
      if (image == null) return;
      String boundary = "movid" + UUID.randomUUID();
      var body = new java.io.ByteArrayOutputStream();
      body.write(
          ("--"
                  + boundary
                  + "\r\n"
                  + "Content-Disposition: form-data; name=\"front_images\";"
                  + " filename=\"body.jpg\"\r\n"
                  + "Content-Type: application/octet-stream\r\n\r\n")
              .getBytes(StandardCharsets.UTF_8));
      body.write(image);
      body.write(("\r\n--" + boundary + "--\r\n").getBytes(StandardCharsets.UTF_8));
      var request =
          HttpRequest.newBuilder(URI.create(aiUrl + "/v1/analyze"))
              .timeout(Duration.ofSeconds(85))
              .header("Content-Type", "multipart/form-data; boundary=" + boundary)
              .POST(HttpRequest.BodyPublishers.ofByteArray(body.toByteArray()))
              .build();
      var response = http.send(request, HttpResponse.BodyHandlers.ofString());
      Map<String, Object> result =
          json.readValue(response.body(), new TypeReference<Map<String, Object>>() {});
      if (response.statusCode() != 200) {
        var detail = result.get("detail");
        Map<?, ?> error = detail instanceof Map ? (Map<?, ?>) detail : Map.of();
        String code = String.valueOf(error.get("code"));
        if (!Set.of("IMAGE_BLURRY", "NO_PERSON", "MULTIPLE_PEOPLE", "NOT_FULL_BODY", "NOT_FRONTAL")
            .contains(code)) code = "AI_FAILED";
        finishFailure(id, code, "사진 분석을 완료하지 못했어요. 사진과 AI 서버 상태를 확인해 주세요.");
        return;
      }
      AnalysisResultValidator.validate(result);
      tx.executeWithoutResult(
          t -> {
            BodyAnalysis a = analyses.findById(id).orElseThrow();
            if (a.getStatus() != BodyAnalysis.Status.pending) return;
            if (a.getCreatedAt().isBefore(now().minusSeconds(90))) {
              a.setStatus(BodyAnalysis.Status.failed);
              a.setErrorCode(BodyAnalysis.ErrorCode.AI_TIMEOUT);
              a.setErrorMessage("분석 시간이 초과됐어요.");
              a.setCompletedAt(now());
              analyses.save(a);
              return;
            }
            Map<String, Object> m =
                json.convertValue(
                    result.get("measures"), new TypeReference<Map<String, Object>>() {});
            result.put("measures", m);
            a.setShoulderTiltDeg(decimal(m.get("shoulder_tilt_deg"), 1));
            a.setPelvisTiltDeg(decimal(m.get("pelvis_tilt_deg"), 1));
            a.setShoulderHipRatio(decimal(m.get("shoulder_hip_ratio"), 2));
            a.setTorsoLegRatio(decimal(m.get("torso_leg_ratio"), 2));
            if (a.getSidePhoto() == null)
              m.put(
                  "unavailable",
                  List.of(obj("key", "neck_forward_deg", "reason", "SIDE_PHOTO_MISSING")));
            a.setUnavailableJson(json.writeValueAsString(m.get("unavailable")));
            a.setJudgementsJson(json.writeValueAsString(result.get("judgements")));
            a.setMeasurementVersion("pixel-dino-v1");
            a.setResultPayload(json.writeValueAsString(result));
            a.setStatus(BodyAnalysis.Status.done);
            a.setCompletedAt(now());
            analyses.save(a);
          });
    } catch (HttpTimeoutException e) {
      finishFailure(id, "AI_TIMEOUT", "분석 시간이 초과됐어요. 다시 시도해 주세요.");
    } catch (Exception e) {
      log.warn("AI integration failed for analysis {}", id, e);
      finishFailure(id, "AI_FAILED", "AI 서버에 연결하지 못했거나 분석에 실패했어요.");
    }
  }

  private BigDecimal decimal(Object v, int scale) {
    return v == null ? null : new BigDecimal(v.toString()).setScale(scale, RoundingMode.HALF_UP);
  }

  private void finishFailure(long id, String code, String message) {
    tx.executeWithoutResult(
        t -> {
          var a = analyses.findById(id).orElseThrow();
          if (a.getStatus() == BodyAnalysis.Status.pending) {
            a.setStatus(BodyAnalysis.Status.failed);
            a.setErrorCode(BodyAnalysis.ErrorCode.valueOf(code));
            a.setErrorMessage(message);
            a.setCompletedAt(now());
            analyses.save(a);
          }
        });
  }

  @Scheduled(fixedDelay = 10000)
  public void expirePending() {
    tx.executeWithoutResult(
        t -> {
          for (var a : analyses.findByStatus(BodyAnalysis.Status.pending)) {
            if (a.getCreatedAt().isBefore(now().minusSeconds(90))) {
              a.setStatus(BodyAnalysis.Status.failed);
              a.setErrorCode(BodyAnalysis.ErrorCode.AI_TIMEOUT);
              a.setErrorMessage("분석 시간이 초과됐어요. 다시 시도해 주세요.");
              a.setCompletedAt(now());
              analyses.save(a);
            }
          }
        });
  }

  private Map<String, Object> view(BodyAnalysis a) {
    Map<String, Object> result =
        a.getResultPayload() == null
            ? new LinkedHashMap<>()
            : json.readValue(a.getResultPayload(), new TypeReference<Map<String, Object>>() {});
    result.putAll(
        obj(
            "analysis_id",
            a.getId(),
            "status",
            a.getStatus().name(),
            "source",
            "photo",
            "photo_id",
            a.getPhoto() == null ? null : a.getPhoto().getId(),
            "side_photo_id",
            a.getSidePhoto() == null ? null : a.getSidePhoto().getId(),
            "goal_body_id",
            null,
            "created_at",
            timestamp(a.getCreatedAt()),
            "completed_at",
            timestamp(a.getCompletedAt()),
            "error_code",
            a.getErrorCode() == null ? null : a.getErrorCode().name(),
            "error_message",
            a.getErrorMessage()));
    result.put(
        "capabilities",
        obj("routine_generation", false, "muscle_classification", false, "goal_comparison", false));
    if (a.getStatus() == BodyAnalysis.Status.done
        && result.get("measures") instanceof Map<?, ?> measures) {
      result.putAll(AnalysisExplanation.describe(measures));
    }
    result.putIfAbsent("judgements", List.of());
    result.putIfAbsent("measures", null);
    return result;
  }

  public Map<String, Object> detail(long uid, long id) {
    return tx.execute(
        t -> {
          access(uid, true);
          var a = analyses.findById(id).orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
          if (!a.getUser().getId().equals(uid)) fail(ErrorCode.NOT_FOUND);
          return view(a);
        });
  }

  public Map<String, Object> history(long uid, int page, int size) {
    if (page < 1 || size < 1 || size > 100) fail(ErrorCode.VALIDATION_FAILED);
    return tx.execute(
        t -> {
          access(uid, true);
          var all = analyses.findByUserIdOrderByIdDesc(uid);
          var list =
              all.stream()
                  .skip((long) (page - 1) * size)
                  .limit(size)
                  .map(
                      a ->
                          obj(
                              "analysis_id",
                              a.getId(),
                              "status",
                              a.getStatus().name(),
                              "created_at",
                              timestamp(a.getCreatedAt()),
                              "balance_score",
                              null,
                              "body_type",
                              null))
                  .toList();
          return obj("items", list, "total", all.size(), "page", page);
        });
  }
}
