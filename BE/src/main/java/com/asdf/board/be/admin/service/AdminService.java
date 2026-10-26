package com.asdf.board.be.admin.service;

import com.asdf.board.be.global.web.Texts;
import com.asdf.board.be.admin.dto.AdminCouponDto;
import com.asdf.board.be.admin.dto.AdminMissionDto;
import com.asdf.board.be.admin.dto.AdminReportDto;
import com.asdf.board.be.admin.dto.AdminReportPageDto;
import com.asdf.board.be.admin.dto.AdminUserDto;
import com.asdf.board.be.admin.dto.AdminUserPageDto;
import com.asdf.board.be.admin.dto.CorrectionCreateRequest;
import com.asdf.board.be.admin.dto.CorrectionPatch;
import com.asdf.board.be.admin.dto.CouponCreateRequest;
import com.asdf.board.be.admin.dto.CouponPatch;
import com.asdf.board.be.admin.dto.ExerciseCreateRequest;
import com.asdf.board.be.admin.dto.ExercisePatch;
import com.asdf.board.be.admin.dto.MissionCreateRequest;
import com.asdf.board.be.admin.dto.MissionPatchRequest;
import com.asdf.board.be.admin.dto.PartnerDto;
import com.asdf.board.be.admin.dto.PartnerPageDto;
import com.asdf.board.be.admin.dto.PartnerPatch;
import com.asdf.board.be.admin.dto.PartnerRequest;
import com.asdf.board.be.admin.dto.ProductCreateRequest;
import com.asdf.board.be.admin.dto.ProductPatch;
import com.asdf.board.be.admin.dto.ReportPatch;
import com.asdf.board.be.community.entity.Report;
import com.asdf.board.be.community.repository.CommentRepository;
import com.asdf.board.be.community.repository.PostRepository;
import com.asdf.board.be.community.repository.ReportRepository;
import com.asdf.board.be.correction.dto.CorrectionExerciseDetailDto;
import com.asdf.board.be.correction.entity.CorrectionExercise;
import com.asdf.board.be.correction.repository.CorrectionExerciseRepository;
import com.asdf.board.be.correction.service.CorrectionService;
import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.partner.dto.NutritionDto;
import com.asdf.board.be.partner.dto.ProductDto;
import com.asdf.board.be.partner.entity.Coupon;
import com.asdf.board.be.partner.entity.Mission;
import com.asdf.board.be.partner.entity.Partner;
import com.asdf.board.be.partner.entity.Product;
import com.asdf.board.be.partner.repository.CouponRepository;
import com.asdf.board.be.partner.repository.MissionRepository;
import com.asdf.board.be.partner.repository.PartnerRepository;
import com.asdf.board.be.partner.repository.ProductRepository;
import com.asdf.board.be.partner.service.PartnerService;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.repository.UserProfileRepository;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.workout.dto.ExerciseDetailDto;
import com.asdf.board.be.workout.entity.Exercise;
import com.asdf.board.be.workout.entity.ExercisePrescription;
import com.asdf.board.be.workout.repository.ExercisePrescriptionRepository;
import com.asdf.board.be.workout.repository.ExerciseRepository;
import com.asdf.board.be.workout.service.ExerciseService;
import java.net.URI;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;

@Service
@RequiredArgsConstructor
public class AdminService {

    private static final List<String> MISSION_TYPES = List.of("workout_days", "workout_count");

    private final UserRepository userRepository;
    private final UserProfileRepository profileRepository;
    private final PartnerRepository partnerRepository;
    private final ProductRepository productRepository;
    private final MissionRepository missionRepository;
    private final CouponRepository couponRepository;
    private final ExerciseRepository exerciseRepository;
    private final ExercisePrescriptionRepository prescriptionRepository;
    private final ExerciseService exerciseService;
    private final CorrectionExerciseRepository correctionRepository;
    private final ReportRepository reportRepository;
    private final PostRepository postRepository;
    private final CommentRepository commentRepository;
    private final JsonMapper jsonMapper;
    private final Clock clock;

    @Transactional(readOnly = true)
    public AdminUserPageDto users(int page, int pageSize) {
        Page<User> result = userRepository.findAll(PageParams.of(page, pageSize, Sort.by(Sort.Direction.DESC, "id")));
        Set<Long> onboarded = profileRepository.userIdsWithProfile(result.getContent().stream().map(User::getId).toList());
        return new AdminUserPageDto(result.getContent().stream().map(u -> toDto(u, onboarded.contains(u.getId()))).toList(),
                page, pageSize, (int) result.getTotalElements());
    }

    @Transactional(readOnly = true)
    public AdminUserDto user(Long id) {
        User user = userRepository.findById(id).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        return toDto(user, profileRepository.existsByUserId(id));
    }

    @Transactional(readOnly = true)
    public PartnerPageDto partners(int page, int pageSize) {
        Page<Partner> result = partnerRepository.findAll(PageParams.of(page, pageSize, Sort.by(Sort.Direction.DESC, "id")));
        return new PartnerPageDto(result.getContent().stream().map(AdminService::toDto).toList(), page, pageSize,
                (int) result.getTotalElements());
    }

    @Transactional
    public PartnerDto createPartner(PartnerRequest r) {
        String name = Texts.required(r.name(), 50);
        period(r.contractStart(), r.contractEnd());
        return toDto(partnerRepository.saveAndFlush(Partner.builder()
                .name(name).contractStart(r.contractStart()).contractEnd(r.contractEnd()).build()));
    }

    @Transactional
    public PartnerDto patchPartner(Long id, PartnerPatch r) {
        Partner partner = partnerRepository.findById(id).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (r.name() != null) {
            partner.setName(Texts.required(r.name(), 50));
        }
        if (r.contractStart() != null) {
            partner.setContractStart(r.contractStart());
        }
        if (r.contractEnd() != null) {
            partner.setContractEnd(r.contractEnd());
        }
        period(partner.getContractStart(), partner.getContractEnd());
        partnerRepository.flush();
        return toDto(partner);
    }

    @Transactional
    public ProductDto createProduct(ProductCreateRequest r) {
        Partner partner = partnerRepository.findById(r.partnerId()).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        period(r.displayFrom(), r.displayTo());
        Product product = Product.builder().partner(partner).category(r.category()).name(Texts.required(r.name(), 100))
                .price(r.price()).linkUrl(url(r.linkUrl(), true)).displayFrom(r.displayFrom()).displayTo(r.displayTo())
                .isAdLabeled(r.isAdLabeled() == null ? Boolean.TRUE : r.isAdLabeled()).build();
        applyNutrition(product, r.nutrition());
        productRepository.saveAndFlush(product);
        return PartnerService.toDto(productRepository.findWithPartner(product.getId()).orElseThrow());
    }

    @Transactional
    public ProductDto patchProduct(Long id, ProductPatch r) {
        Product product = productRepository.findWithPartner(id).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (r.category() != null) {
            product.setCategory(r.category());
        }
        if (r.name() != null) {
            product.setName(Texts.required(r.name(), 100));
        }
        if (r.price() != null) {
            product.setPrice(r.price());
        }
        if (r.nutrition() != null) {
            applyNutrition(product, r.nutrition());
        }
        if (r.linkUrl() != null) {
            product.setLinkUrl(url(r.linkUrl(), true));
        }
        if (r.displayFrom() != null) {
            product.setDisplayFrom(r.displayFrom());
        }
        if (r.displayTo() != null) {
            product.setDisplayTo(r.displayTo());
        }
        if (r.isAdLabeled() != null) {
            product.setIsAdLabeled(r.isAdLabeled());
        }
        period(product.getDisplayFrom(), product.getDisplayTo());
        productRepository.flush();
        return PartnerService.toDto(product);
    }

    @Transactional
    public AdminMissionDto createMission(MissionCreateRequest r) {
        Coupon coupon = r.couponId() == null ? null
                : couponRepository.findById(r.couponId()).orElseThrow(ApiException.of(ErrorCode.VALIDATION_FAILED));
        Mission mission = missionRepository.saveAndFlush(Mission.builder().title(Texts.required(r.title(), 100))
                .conditionJson(condition(r.conditionJson())).periodDays(r.periodDays()).coupon(coupon)
                .isActive(r.isActive() == null ? Boolean.TRUE : r.isActive()).build());
        return toDto(mission);
    }

    @Transactional
    public AdminMissionDto patchMission(Long id, MissionPatchRequest r) {
        Mission mission = missionRepository.findById(id).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (r.title() != null) {
            mission.setTitle(Texts.required(r.title(), 100));
        }
        if (r.conditionJson() != null) {
            mission.setConditionJson(condition(r.conditionJson()));
        }
        if (r.periodDays() != null) {
            mission.setPeriodDays(r.periodDays());
        }
        if (r.couponId() != null) {
            mission.setCoupon(couponRepository.findById(r.couponId())
                    .orElseThrow(ApiException.of(ErrorCode.VALIDATION_FAILED)));
        }
        if (r.isActive() != null) {
            mission.setIsActive(r.isActive());
        }
        missionRepository.flush();
        return toDto(mission);
    }

    @Transactional
    public AdminCouponDto createCoupon(CouponCreateRequest r) {
        Partner partner = partnerRepository.findById(r.partnerId()).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        return toDto(couponRepository.saveAndFlush(Coupon.builder().partner(partner).title(Texts.required(r.title(), 100))
                .discountDesc(Texts.required(r.discountDesc(), 200)).validDays(r.validDays()).build()));
    }

    @Transactional
    public AdminCouponDto patchCoupon(Long id, CouponPatch r) {
        Coupon coupon = couponRepository.findById(id).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (r.title() != null) {
            coupon.setTitle(Texts.required(r.title(), 100));
        }
        if (r.discountDesc() != null) {
            coupon.setDiscountDesc(Texts.required(r.discountDesc(), 200));
        }
        if (r.validDays() != null) {
            coupon.setValidDays(r.validDays());
        }
        couponRepository.flush();
        return toDto(coupon);
    }

    @Transactional
    public ExerciseDetailDto createExercise(ExerciseCreateRequest r) {
        sets(r.minSets(), r.maxSets());
        if (exerciseRepository.existsByName(Texts.required(r.name(), 50))) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        Exercise exercise = exerciseRepository.saveAndFlush(Exercise.builder().name(Texts.required(r.name(), 50))
                .targetPart(r.targetPart()).equipment(r.equipment()).difficulty(r.difficulty())
                .description(Texts.blankToNull(r.description())).mediaUrl(url(r.mediaUrl(), false)).isActive(true).build());
        for (ExperienceLevel level : ExperienceLevel.values()) {
            prescriptionRepository.save(ExercisePrescription.builder().exercise(exercise).experienceLevel(level)
                    .minSets(r.minSets()).maxSets(r.maxSets()).build());
        }
        prescriptionRepository.flush();
        return exerciseService.detailOf(exercise);
    }

    @Transactional
    public ExerciseDetailDto patchExercise(Long id, ExercisePatch r) {
        Exercise exercise = exerciseRepository.findById(id).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (r.name() != null) {
            if (exerciseRepository.existsByNameAndIdNot(Texts.required(r.name(), 50), id)) {
                throw new ApiException(ErrorCode.VALIDATION_FAILED);
            }
            exercise.setName(Texts.required(r.name(), 50));
        }
        if (r.targetPart() != null) {
            exercise.setTargetPart(r.targetPart());
        }
        if (r.difficulty() != null) {
            exercise.setDifficulty(r.difficulty());
        }
        if (r.equipment() != null) {
            exercise.setEquipment(r.equipment());
        }
        if (r.description() != null) {
            exercise.setDescription(Texts.blankToNull(r.description()));
        }
        if (r.mediaUrl() != null) {
            exercise.setMediaUrl(url(r.mediaUrl(), false));
        }
        if (r.minSets() != null || r.maxSets() != null) {
            for (ExercisePrescription p : prescriptionRepository.findByIdExerciseId(id)) {
                int min = r.minSets() != null ? r.minSets() : p.getMinSets();
                int max = r.maxSets() != null ? r.maxSets() : p.getMaxSets();
                sets(min, max);
                p.setMinSets(min);
                p.setMaxSets(max);
            }
        }
        exerciseRepository.flush();
        prescriptionRepository.flush();
        return exerciseService.detailOf(exercise);
    }

    @Transactional
    public CorrectionExerciseDetailDto createCorrection(CorrectionCreateRequest r) {
        CorrectionExercise saved = correctionRepository.saveAndFlush(CorrectionExercise.builder()
                .targetIssue(r.targetIssue()).name(Texts.required(r.name(), 50)).method(Texts.required(r.method(), 1000))
                .durationOrReps(Texts.required(r.durationOrReps(), 30)).mediaUrl(url(r.mediaUrl(), false)).isActive(true).build());
        return CorrectionService.detail(saved);
    }

    @Transactional
    public CorrectionExerciseDetailDto patchCorrection(Long id, CorrectionPatch r) {
        CorrectionExercise c = correctionRepository.findById(id).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (r.targetIssue() != null) {
            c.setTargetIssue(r.targetIssue());
        }
        if (r.name() != null) {
            c.setName(Texts.required(r.name(), 50));
        }
        if (r.method() != null) {
            c.setMethod(Texts.required(r.method(), 1000));
        }
        if (r.durationOrReps() != null) {
            c.setDurationOrReps(Texts.required(r.durationOrReps(), 30));
        }
        if (r.mediaUrl() != null) {
            c.setMediaUrl(url(r.mediaUrl(), false));
        }
        correctionRepository.flush();
        return CorrectionService.detail(c);
    }

    @Transactional(readOnly = true)
    public AdminReportPageDto reports(Report.Status status, int page, int pageSize) {
        var pageable = PageParams.of(page, pageSize, Sort.by(Sort.Direction.DESC, "id"));
        Page<Report> result = status == null ? reportRepository.findAll(pageable) : reportRepository.findByStatus(status, pageable);
        return new AdminReportPageDto(result.getContent().stream().map(AdminService::toDto).toList(), page, pageSize,
                (int) result.getTotalElements());
    }

    @Transactional
    public AdminReportDto patchReport(Long adminId, Long id, ReportPatch r) {
        if (r.status() == Report.Status.pending) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        Report report = reportRepository.findById(id).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        report.setStatus(r.status());
        report.setHandledBy(userRepository.getReferenceById(adminId));
        report.setHandledAt(LocalDateTime.now(clock));
        reportRepository.flush();
        Long targetId = report.getTargetId();
        boolean post = report.getTargetType() == Report.TargetType.post;
        if (r.status() == Report.Status.rejected) {
            if (post) {
                postRepository.unhide(targetId);
            } else {
                commentRepository.unhide(targetId);
            }
        } else if (post) {
            postRepository.hide(targetId, LocalDateTime.now(clock));
        } else {
            commentRepository.hide(targetId, LocalDateTime.now(clock));
        }
        return toDto(reportRepository.findById(id).orElseThrow());
    }

    private static void sets(int min, int max) {
        if (min > max) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
    }

    private static void period(LocalDate from, LocalDate to) {
        if (from.isAfter(to)) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
    }

    private static String url(String value, boolean required) {
        if (value == null || value.isBlank()) {
            if (required) {
                throw new ApiException(ErrorCode.VALIDATION_FAILED);
            }
            return null;
        }
        try {
            URI uri = URI.create(value.strip());
            String scheme = uri.getScheme();
            if (value.strip().length() > 500 || uri.getHost() == null || scheme == null
                    || !(scheme.equalsIgnoreCase("http") || scheme.equalsIgnoreCase("https"))) {
                throw new ApiException(ErrorCode.VALIDATION_FAILED);
            }
            return value.strip();
        } catch (IllegalArgumentException e) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
    }

    private String condition(Map<String, Object> value) {
        Object type = value.get("type");
        Object count = value.get("count");
        if (!(type instanceof String t) || !MISSION_TYPES.contains(t)
                || !(count instanceof Integer c) || c < 1 || c > 1000) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        return jsonMapper.writeValueAsString(Map.of("type", t, "count", c));
    }

    private static void applyNutrition(Product product, NutritionDto n) {
        product.setKcal(n == null ? null : n.kcal());
        product.setCarbG(n == null ? null : n.carbG());
        product.setProteinG(n == null ? null : n.proteinG());
        product.setFatG(n == null ? null : n.fatG());
    }

    @SuppressWarnings("unchecked")
    private AdminMissionDto toDto(Mission m) {
        return new AdminMissionDto(m.getId(), m.getTitle(), jsonMapper.readValue(m.getConditionJson(), Map.class),
                m.getPeriodDays(), m.getCoupon() == null ? null : m.getCoupon().getId(), m.getIsActive());
    }

    private static AdminCouponDto toDto(Coupon c) {
        return new AdminCouponDto(c.getId(), c.getPartner().getId(), c.getTitle(), c.getDiscountDesc(), c.getValidDays());
    }

    private static PartnerDto toDto(Partner p) {
        return new PartnerDto(p.getId(), p.getName(), p.getContractStart(), p.getContractEnd());
    }

    private static AdminReportDto toDto(Report r) {
        return new AdminReportDto(r.getId(), r.getTargetType().name(), r.getTargetId(), r.getReason().name(),
                r.getDetail(), r.getReporter().getId(), r.getStatus().name(), Times.offset(r.getCreatedAt()));
    }

    private static AdminUserDto toDto(User u, boolean onboarded) {
        return new AdminUserDto(u.getId(), u.getEmail(), u.getNickname(), u.getRole().name(),
                onboarded, Times.offset(u.getCreatedAt()), Times.offset(u.getDeletedAt()));
    }
}
