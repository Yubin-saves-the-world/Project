package com.asdf.board.be.body.integration;

import com.asdf.board.be.global.exception.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequiredArgsConstructor
public class BodyIntegrationController {
  private final BodyIntegrationService service;

  public record AnalysisRequest(
      @NotNull @Positive Long photoId, @Positive Long sidePhotoId, @Positive Long goalBodyId) {}

  @PostMapping("/api/photos")
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> upload(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam MultipartFile image,
      @RequestParam String type,
      @RequestParam(defaultValue = "front") String side)
      throws Exception {
    return service.upload(Long.parseLong(jwt.getSubject()), image, type, side);
  }

  @GetMapping("/api/photos")
  public Map<String, Object> photos(
      @AuthenticationPrincipal Jwt jwt, @RequestParam(defaultValue = "current") String type) {
    return service.listPhotos(Long.parseLong(jwt.getSubject()), type);
  }

  @DeleteMapping("/api/photos/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable long id) {
    var r = service.deletePhotos(Long.parseLong(jwt.getSubject()), id, "current");
    if (((Number) r.get("skipped_count")).intValue() > 0)
      throw new ApiException(ErrorCode.ANALYSIS_IN_PROGRESS);
  }

  @DeleteMapping("/api/photos")
  public Map<String, Object> deleteAll(
      @AuthenticationPrincipal Jwt jwt, @RequestParam(defaultValue = "current") String type) {
    return service.deletePhotos(Long.parseLong(jwt.getSubject()), null, type);
  }

  @GetMapping("/api/photo-files/{id}")
  public ResponseEntity<byte[]> file(
      @PathVariable long id, @RequestParam long expires, @RequestParam String signature) {
    var f = service.file(id, expires, signature);
    return ResponseEntity.ok()
        .contentType(MediaType.parseMediaType(f.contentType()))
        .cacheControl(CacheControl.noStore())
        .body(f.bytes());
  }

  @PostMapping("/api/body-analyses/photo")
  @ResponseStatus(HttpStatus.ACCEPTED)
  public Map<String, Object> start(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody AnalysisRequest r) {
    return service.start(
        Long.parseLong(jwt.getSubject()), r.photoId(), r.sidePhotoId(), r.goalBodyId());
  }

  @GetMapping("/api/body-analyses/usage")
  public Map<String, Object> usage(@AuthenticationPrincipal Jwt jwt) {
    return service.usage(Long.parseLong(jwt.getSubject()));
  }

  @GetMapping("/api/body-analyses/{id}")
  public Map<String, Object> detail(@AuthenticationPrincipal Jwt jwt, @PathVariable long id) {
    return service.detail(Long.parseLong(jwt.getSubject()), id);
  }

  @GetMapping("/api/body-analyses")
  public Map<String, Object> history(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(defaultValue = "1") int page,
      @RequestParam(name = "page_size", defaultValue = "20") int size) {
    return service.history(Long.parseLong(jwt.getSubject()), page, size);
  }

  @GetMapping("/api/goal-bodies")
  public void goal() {
    throw new ApiException(ErrorCode.GOAL_NOT_FOUND);
  }
}
