package com.asdf.board.be.diet.service;

import com.asdf.board.be.body.entity.BodyAnalysis;
import com.asdf.board.be.body.repository.BodyAnalysisRepository;
import com.asdf.board.be.diet.dto.DietItemDto;
import com.asdf.board.be.diet.dto.DietPlanDto;
import com.asdf.board.be.diet.dto.DietPlanListDto;
import com.asdf.board.be.diet.dto.MealDto;
import com.asdf.board.be.diet.dto.ProductMiniDto;
import com.asdf.board.be.diet.entity.DietItem;
import com.asdf.board.be.diet.entity.DietMeal;
import com.asdf.board.be.diet.entity.DietPlan;
import com.asdf.board.be.diet.repository.DietItemRepository;
import com.asdf.board.be.diet.repository.DietMealRepository;
import com.asdf.board.be.diet.repository.DietPlanRepository;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.partner.entity.Product;
import com.asdf.board.be.partner.repository.ProductRepository;
import com.asdf.board.be.user.entity.UserAllergy;
import com.asdf.board.be.user.entity.UserProfile;
import com.asdf.board.be.user.repository.UserAllergyRepository;
import com.asdf.board.be.user.repository.UserProfileRepository;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.user.service.AccessGuard;
import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DietService {

    private static final int DAYS = 7;

    private final DietPlanRepository planRepository;
    private final DietMealRepository mealRepository;
    private final DietItemRepository itemRepository;
    private final BodyAnalysisRepository analysisRepository;
    private final UserProfileRepository profileRepository;
    private final UserAllergyRepository allergyRepository;
    private final UserRepository userRepository;
    private final ProductRepository productRepository;
    private final DietPlanner planner;
    private final AccessGuard accessGuard;
    private final Clock clock;

    @Transactional
    public DietPlanListDto create(Long userId, Long analysisId) {
        accessGuard.requireOnboarded(userId);
        BodyAnalysis analysis = analysisRepository.findByIdAndUserId(analysisId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        if (analysis.getStatus() != BodyAnalysis.Status.done) {
            throw new ApiException(ErrorCode.ANALYSIS_NOT_READY);
        }
        userRepository.findByIdForUpdate(userId).orElseThrow(ApiException.of(ErrorCode.UNAUTHORIZED));
        UserProfile profile = profileRepository.findFirstByUserIdOrderByIdDesc(userId)
                .orElseThrow(ApiException.of(ErrorCode.ONBOARDING_REQUIRED));
        Set<String> excluded = allergyRepository.findByUserIdOrderByIdAsc(userId).stream()
                .map(UserAllergy::getItem).collect(Collectors.toSet());
        LocalDate today = LocalDate.now(clock);

        List<Long> old = planRepository.findByUserIdAndPlanDateGreaterThanEqualOrderByPlanDateAsc(userId, today)
                .stream().map(DietPlan::getId).toList();
        if (!old.isEmpty()) {
            planRepository.deleteItems(old);
            planRepository.deleteMeals(old);
            planRepository.deletePlans(old);
        }

        DietPlanner.Macros macros = planner.macros(profile);
        List<Product> products = productRepository
                .findByCategoryAndDisplayFromLessThanEqualAndDisplayToGreaterThanEqualOrderByIdAsc(
                        Product.Category.food, today, today);
        List<DietPlan> saved = new ArrayList<>();
        for (int day = 0; day < DAYS; day++) {
            DietPlan plan = planRepository.save(DietPlan.builder()
                    .user(userRepository.getReferenceById(userId)).analysis(analysis).planDate(today.plusDays(day))
                    .targetKcal(macros.targetKcal()).carbG(macros.carbG()).proteinG(macros.proteinG()).fatG(macros.fatG())
                    .build());
            for (DietPlanner.PlannedMeal planned : planner.meals(macros.targetKcal(), day, excluded)) {
                DietMeal meal = mealRepository.save(DietMeal.builder()
                        .plan(plan).mealType(planned.type()).totalKcal(planned.totalKcal()).build());
                int index = 0;
                for (DietPlanner.PlannedItem item : planned.items()) {
                    Product product = planned.type() == DietMeal.MealType.snack && index == 0 && !products.isEmpty()
                            ? products.get(day % products.size()) : null;
                    itemRepository.save(DietItem.builder().meal(meal).foodName(item.foodName())
                            .amount(item.amount()).kcal(item.kcal()).product(product).build());
                    index++;
                }
            }
            saved.add(plan);
        }
        planRepository.flush();
        return new DietPlanListDto(analysisId, toDtos(saved));
    }

    @Transactional(readOnly = true)
    public DietPlanDto getByDate(Long userId, LocalDate date) {
        accessGuard.requireOnboarded(userId);
        LocalDate target = date == null ? LocalDate.now(clock) : date;
        DietPlan plan = planRepository.findByUserIdAndPlanDate(userId, target)
                .orElseThrow(ApiException.of(ErrorCode.DIET_NOT_FOUND));
        return toDtos(List.of(plan)).get(0);
    }

    @Transactional(readOnly = true)
    public DietPlanDto get(Long userId, Long planId) {
        accessGuard.requireOnboarded(userId);
        DietPlan plan = planRepository.findByIdAndUserId(planId, userId)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        return toDtos(List.of(plan)).get(0);
    }

    private List<DietPlanDto> toDtos(Collection<DietPlan> plans) {
        if (plans.isEmpty()) {
            return List.of();
        }
        List<Long> planIds = plans.stream().map(DietPlan::getId).toList();
        List<DietMeal> meals = mealRepository.findByPlanIdIn(planIds);
        Map<Long, List<DietItem>> itemsByMeal = new HashMap<>();
        if (!meals.isEmpty()) {
            itemRepository.findWithProduct(meals.stream().map(DietMeal::getId).toList())
                    .forEach(i -> itemsByMeal.computeIfAbsent(i.getMeal().getId(), k -> new ArrayList<>()).add(i));
        }
        Map<Long, List<DietMeal>> mealsByPlan = new HashMap<>();
        meals.stream().sorted(Comparator.comparing(DietMeal::getMealType))
                .forEach(m -> mealsByPlan.computeIfAbsent(m.getPlan().getId(), k -> new ArrayList<>()).add(m));
        return plans.stream().sorted(Comparator.comparing(DietPlan::getPlanDate)).map(p -> new DietPlanDto(
                p.getId(), p.getPlanDate(), p.getTargetKcal(), p.getCarbG(), p.getProteinG(), p.getFatG(),
                mealsByPlan.getOrDefault(p.getId(), List.of()).stream().map(m -> new MealDto(
                        m.getMealType().name(), m.getTotalKcal(),
                        itemsByMeal.getOrDefault(m.getId(), List.of()).stream().map(DietService::item).toList())).toList()))
                .toList();
    }

    private static DietItemDto item(DietItem i) {
        Product p = i.getProduct();
        return new DietItemDto(i.getId(), i.getFoodName(), i.getAmount(), i.getKcal(),
                p == null ? null : new ProductMiniDto(p.getId(), p.getName(), p.getLinkUrl(), p.getIsAdLabeled()));
    }
}
