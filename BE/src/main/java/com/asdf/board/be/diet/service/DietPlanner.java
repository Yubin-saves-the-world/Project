package com.asdf.board.be.diet.service;

import com.asdf.board.be.global.web.Texts;
import com.asdf.board.be.diet.entity.DietMeal.MealType;
import com.asdf.board.be.user.entity.UserProfile;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Component;

@Component
public class DietPlanner {

    public enum Role { carb, protein, side, snack }

    public record Food(String name, int kcalPer100g, int defaultGrams, int unitGrams, Role role, Set<String> allergens) {
    }

    public record Macros(int targetKcal, int carbG, int proteinG, int fatG) {
    }

    public record PlannedItem(String foodName, String amount, int kcal) {
    }

    public record PlannedMeal(MealType type, List<PlannedItem> items) {
        public int totalKcal() {
            return items.stream().mapToInt(PlannedItem::kcal).sum();
        }
    }

    private static final Map<MealType, Double> SHARE = Map.of(
            MealType.breakfast, 0.25, MealType.lunch, 0.35, MealType.dinner, 0.30, MealType.snack, 0.10);

    private static final Map<MealType, List<Role>> COMPOSITION = Map.of(
            MealType.breakfast, List.of(Role.carb, Role.protein, Role.side),
            MealType.lunch, List.of(Role.carb, Role.protein, Role.side),
            MealType.dinner, List.of(Role.carb, Role.protein, Role.side),
            MealType.snack, List.of(Role.snack, Role.snack));

    private static final Map<MealType, List<Food>> CATALOG = new EnumMap<>(MealType.class);

    static {
        CATALOG.put(MealType.breakfast, List.of(
                food("오트밀죽", 70, 250, 0, Role.carb, "귀리", "밀", "글루텐"),
                food("통밀식빵", 250, 70, 35, Role.carb, "밀", "글루텐"),
                food("현미밥", 150, 210, 0, Role.carb),
                food("삶은 달걀", 150, 100, 50, Role.protein, "계란", "달걀", "난류"),
                food("그릭요거트", 95, 150, 0, Role.protein, "우유", "유제품", "락토오스"),
                food("두부", 90, 150, 0, Role.protein, "대두", "콩"),
                food("바나나", 90, 120, 0, Role.side),
                food("방울토마토", 20, 150, 0, Role.side),
                food("사과", 55, 150, 0, Role.side)));
        CATALOG.put(MealType.lunch, List.of(
                food("현미밥", 150, 210, 0, Role.carb),
                food("보리밥", 140, 210, 0, Role.carb),
                food("고구마", 130, 150, 0, Role.carb),
                food("닭가슴살구이", 165, 150, 0, Role.protein, "닭고기", "가금류"),
                food("연어구이", 200, 130, 0, Role.protein, "생선", "연어"),
                food("소고기 우둔살", 160, 130, 0, Role.protein, "소고기", "쇠고기"),
                food("돼지안심구이", 150, 130, 0, Role.protein, "돼지고기"),
                food("오징어볶음", 120, 150, 0, Role.protein, "오징어", "해산물", "연체류"),
                food("샐러드", 30, 150, 0, Role.side),
                food("브로콜리", 35, 120, 0, Role.side),
                food("된장국", 25, 200, 0, Role.side, "대두", "콩")));
        CATALOG.put(MealType.dinner, List.of(
                food("현미밥", 150, 180, 0, Role.carb),
                food("고구마", 130, 150, 0, Role.carb),
                food("귀리밥", 145, 180, 0, Role.carb, "귀리"),
                food("닭가슴살 샐러드", 120, 200, 0, Role.protein, "닭고기", "가금류"),
                food("대구구이", 110, 150, 0, Role.protein, "생선", "대구"),
                food("새우구이", 100, 130, 0, Role.protein, "새우", "갑각류", "해산물"),
                food("계란찜", 100, 150, 0, Role.protein, "계란", "달걀", "난류"),
                food("두부구이", 130, 150, 0, Role.protein, "대두", "콩"),
                food("시금치나물", 40, 100, 0, Role.side),
                food("야채볶음", 60, 150, 0, Role.side),
                food("미역국", 20, 200, 0, Role.side)));
        CATALOG.put(MealType.snack, List.of(
                food("아몬드", 600, 25, 0, Role.snack, "아몬드", "견과류"),
                food("바나나", 90, 120, 0, Role.snack),
                food("그릭요거트", 95, 150, 0, Role.snack, "우유", "유제품", "락토오스"),
                food("삶은 달걀", 150, 100, 50, Role.snack, "계란", "달걀", "난류"),
                food("방울토마토", 20, 150, 0, Role.snack),
                food("무가당 두유", 45, 190, 0, Role.snack, "대두", "콩"),
                food("프로틴 쉐이크", 110, 250, 0, Role.snack, "우유", "유제품", "락토오스"),
                food("사과", 55, 150, 0, Role.snack)));
    }

    private static Food food(String name, int kcalPer100g, int grams, int unit, Role role, String... allergens) {
        return new Food(name, kcalPer100g, grams, unit, role, Set.of(allergens));
    }

    public Macros macros(UserProfile profile) {
        double weight = profile.getWeightKg().doubleValue();
        double height = profile.getHeightCm().doubleValue();
        int age = profile.getAge();
        double base = 10 * weight + 6.25 * height - 5 * age;
        double bmr = switch (profile.getGender()) {
            case male -> base + 5;
            case female -> base - 161;
            case none -> base - 78;
        };
        int frequency = profile.getWeeklyFrequency();
        double activity = frequency <= 2 ? 1.375 : frequency <= 4 ? 1.55 : frequency <= 6 ? 1.725 : 1.9;
        double tdee = bmr * activity;
        double goalFactor = switch (profile.getGoalType()) {
            case muscle -> 1.10;
            case diet -> 0.80;
            case posture -> 1.0;
        };
        int floor = profile.getGender() == UserProfile.Gender.male ? 1500 : 1200;
        int target = (int) Math.max(floor, Math.round(tdee * goalFactor / 10.0) * 10);
        double proteinPerKg = profile.getGoalType() == UserProfile.GoalType.posture ? 1.6 : 2.0;
        int protein = (int) Math.round(weight * proteinPerKg);
        int fat = (int) Math.round(target * 0.25 / 9);
        int carb = Math.max(0, (int) Math.round((target - protein * 4.0 - fat * 9.0) / 4));
        return new Macros(target, carb, protein, fat);
    }

    public List<PlannedMeal> meals(int targetKcal, int dayIndex, Set<String> excluded) {
        List<PlannedMeal> result = new ArrayList<>();
        for (MealType type : MealType.values()) {
            List<Food> foods = CATALOG.get(type).stream().filter(f -> allowed(f, excluded)).toList();
            List<Food> picked = new ArrayList<>();
            int offset = dayIndex + type.ordinal() * 2;
            for (Role role : COMPOSITION.get(type)) {
                List<Food> candidates = foods.stream().filter(f -> f.role() == role && !picked.contains(f)).toList();
                if (!candidates.isEmpty()) {
                    picked.add(candidates.get(Math.floorMod(offset + picked.size(), candidates.size())));
                }
            }
            double defaultKcal = picked.stream().mapToDouble(f -> f.kcalPer100g() * f.defaultGrams() / 100.0).sum();
            double factor = defaultKcal == 0 ? 1
                    : Math.min(2.5, Math.max(0.5, targetKcal * SHARE.get(type) / defaultKcal));
            List<PlannedItem> items = picked.stream().map(f -> scale(f, factor)).toList();
            result.add(new PlannedMeal(type, items));
        }
        return result;
    }

    private static PlannedItem scale(Food food, double factor) {
        if (food.unitGrams() > 0) {
            int count = Math.max(1, (int) Math.round(food.defaultGrams() * factor / food.unitGrams()));
            int grams = count * food.unitGrams();
            return new PlannedItem(food.name(), count + "개", kcal(food, grams));
        }
        int grams = (int) Math.max(10, Math.round(food.defaultGrams() * factor / 10.0) * 10);
        return new PlannedItem(food.name(), grams + "g", kcal(food, grams));
    }

    private static int kcal(Food food, int grams) {
        return (int) Math.round(food.kcalPer100g() * grams / 100.0);
    }

    private static boolean allowed(Food food, Set<String> excluded) {
        for (String raw : excluded) {
            String item = Texts.compact(raw);
            if (item.isEmpty()) {
                continue;
            }
            if (Texts.compact(food.name()).contains(item)) {
                return false;
            }
            for (String allergen : food.allergens()) {
                if (allergen.contains(item) || item.contains(allergen)) {
                    return false;
                }
            }
        }
        return true;
    }
}
