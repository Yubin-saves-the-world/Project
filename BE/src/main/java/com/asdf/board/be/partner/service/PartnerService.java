package com.asdf.board.be.partner.service;

import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.time.Times;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.partner.dto.MissionDto;
import com.asdf.board.be.partner.dto.MissionProgressDto;
import com.asdf.board.be.partner.dto.NutritionDto;
import com.asdf.board.be.partner.dto.ProductDto;
import com.asdf.board.be.partner.dto.ProductPageDto;
import com.asdf.board.be.partner.dto.UserCouponDto;
import com.asdf.board.be.partner.dto.UserCouponPageDto;
import com.asdf.board.be.partner.entity.Mission;
import com.asdf.board.be.partner.entity.Product;
import com.asdf.board.be.partner.entity.UserCoupon;
import com.asdf.board.be.partner.entity.UserMission;
import com.asdf.board.be.partner.repository.MissionRepository;
import com.asdf.board.be.partner.repository.ProductRepository;
import com.asdf.board.be.partner.repository.UserCouponRepository;
import com.asdf.board.be.partner.repository.UserMissionRepository;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import com.asdf.board.be.workout.entity.WorkoutLog;
import com.asdf.board.be.workout.repository.WorkoutLogRepository;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;

@Service
@RequiredArgsConstructor
public class PartnerService {

    private final ProductRepository productRepository;
    private final MissionRepository missionRepository;
    private final UserMissionRepository userMissionRepository;
    private final UserCouponRepository userCouponRepository;
    private final WorkoutLogRepository workoutLogRepository;
    private final UserRepository userRepository;
    private final AccessGuard accessGuard;
    private final JsonMapper jsonMapper;
    private final Clock clock;

    @Transactional(readOnly = true)
    public ProductPageDto products(Long userId, Product.Category category, int page, int pageSize) {
        accessGuard.requireOnboarded(userId);
        LocalDate today = LocalDate.now(clock);
        var pageable = PageParams.of(page, pageSize, Sort.unsorted());
        Page<Product> result = category == null
                ? productRepository.visible(today, pageable)
                : productRepository.visibleByCategory(category, today, pageable);
        return new ProductPageDto(result.getContent().stream().map(PartnerService::toDto).toList(),
                page, pageSize, (int) result.getTotalElements());
    }

    @Transactional(readOnly = true)
    public ProductDto product(Long userId, Long productId) {
        accessGuard.requireOnboarded(userId);
        LocalDate today = LocalDate.now(clock);
        return productRepository.findWithPartner(productId)
                .filter(p -> !p.getDisplayFrom().isAfter(today) && !p.getDisplayTo().isBefore(today))
                .map(PartnerService::toDto).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
    }

    @Transactional
    public MissionDto currentMission(Long userId) {
        accessGuard.requireOnboarded(userId);
        Mission mission = missionRepository.findFirstByIsActiveTrueOrderByIdDesc()
                .orElseThrow(ApiException.of(ErrorCode.NO_ACTIVE_MISSION));
        LocalDateTime now = LocalDateTime.now(clock);
        UserMission mine = userMissionRepository.findFirstByUserIdAndMissionIdOrderByIdDesc(userId, mission.getId())
                .filter(um -> um.getCompletedAt() != null || um.getEndsAt().isAfter(now))
                .orElseGet(() -> userMissionRepository.saveAndFlush(UserMission.builder()
                        .user(userRepository.getReferenceById(userId)).mission(mission)
                        .startedAt(now).endsAt(now.plusDays(mission.getPeriodDays())).build()));
        return new MissionDto(mission.getId(), mission.getTitle(), mission.getPeriodDays(), target(condition(mission)),
                mission.getCoupon() == null ? null : mission.getCoupon().getTitle(),
                Times.offset(mine.getStartedAt()), Times.offset(mine.getEndsAt()));
    }

    @Transactional
    public MissionProgressDto progress(Long userId, Long missionId) {
        accessGuard.requireOnboarded(userId);
        Mission mission = missionRepository.findById(missionId).orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        UserMission mine = userMissionRepository.findFirstByUserIdAndMissionIdOrderByIdDesc(userId, missionId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        Map<String, Object> condition = condition(mission);
        int target = target(condition);
        LocalDateTime now = LocalDateTime.now(clock);
        int current;
        if (mine.getCompletedAt() != null) {
            current = Math.max(mine.getProgressCount(), target);
        } else {
            current = count(userId, condition, mine, now);
            mine.setProgressCount(Math.min(current, target));
            if (current >= target) {
                mine.setCompletedAt(now);
                issueCoupon(userId, mission, mine, now.toLocalDate());
            }
            userMissionRepository.flush();
        }
        int shown = Math.min(current, target);
        return new MissionProgressDto(missionId, shown, target, Math.min(100, shown * 100 / target),
                mine.getCompletedAt() != null);
    }

    @Transactional(readOnly = true)
    public UserCouponPageDto coupons(Long userId, UserCoupon.Status status, int page, int pageSize) {
        accessGuard.requireOnboarded(userId);
        LocalDate today = LocalDate.now(clock);
        List<UserCouponDto> all = userCouponRepository.findAllOfUser(userId).stream()
                .map(c -> toDto(c, today)).filter(c -> status == null || c.status().equals(status.name())).toList();
        return new UserCouponPageDto(PageParams.slice(all, page, pageSize), page, pageSize, all.size());
    }

    @Transactional(readOnly = true)
    public UserCouponDto coupon(Long userId, Long id) {
        accessGuard.requireOnboarded(userId);
        return userCouponRepository.findOfUser(id, userId).map(c -> toDto(c, LocalDate.now(clock)))
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
    }

    private void issueCoupon(Long userId, Mission mission, UserMission mine, LocalDate today) {
        if (mission.getCoupon() == null || userCouponRepository.existsByUserMissionId(mine.getId())) {
            return;
        }
        userCouponRepository.save(UserCoupon.builder()
                .user(userRepository.getReferenceById(userId)).coupon(mission.getCoupon()).userMission(mine)
                .validUntil(today.plusDays(mission.getCoupon().getValidDays())).build());
    }

    private int count(Long userId, Map<String, Object> condition, UserMission mine, LocalDateTime now) {
        LocalDateTime to = (now.isBefore(mine.getEndsAt()) ? now : mine.getEndsAt()).plusSeconds(1);
        List<WorkoutLog> logs = workoutLogRepository.findByUserIdAndStatusAndCompletedAtBetween(
                userId, WorkoutLog.Status.completed, mine.getStartedAt(), to);
        return "workout_count".equals(String.valueOf(condition.get("type")))
                ? logs.size()
                : (int) logs.stream().map(WorkoutLog::getWorkoutDate).distinct().count();
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> condition(Mission mission) {
        return jsonMapper.readValue(mission.getConditionJson(), Map.class);
    }

    private static int target(Map<String, Object> condition) {
        Object count = condition.get("count");
        return count instanceof Number n && n.intValue() > 0 ? n.intValue() : 1;
    }

    public static ProductDto toDto(Product p) {
        boolean hasNutrition = p.getKcal() != null || p.getCarbG() != null || p.getProteinG() != null || p.getFatG() != null;
        return new ProductDto(p.getId(), p.getName(), p.getPrice(), p.getCategory().name(), p.getPartner().getName(),
                hasNutrition ? new NutritionDto(p.getKcal(), p.getCarbG(), p.getProteinG(), p.getFatG()) : null,
                p.getLinkUrl(), p.getIsAdLabeled());
    }

    private static UserCouponDto toDto(UserCoupon c, LocalDate today) {
        UserCoupon.Status status = c.getStatus() == UserCoupon.Status.available && c.getValidUntil().isBefore(today)
                ? UserCoupon.Status.expired : c.getStatus();
        return new UserCouponDto(c.getId(), c.getCoupon().getTitle(), c.getCoupon().getDiscountDesc(),
                c.getCoupon().getPartner().getName(), status.name(), c.getValidUntil());
    }
}
