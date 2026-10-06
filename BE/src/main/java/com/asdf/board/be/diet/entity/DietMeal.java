package com.asdf.board.be.diet.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "diet_meals", uniqueConstraints = {@UniqueConstraint(name = "uq_meal_type", columnNames = {"plan_id", "meal_type"})})
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class DietMeal {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "meal_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "plan_id", nullable = false)
    private DietPlan plan;

    @Enumerated(EnumType.STRING)
    @Column(name = "meal_type", nullable = false, length = 10)
    private MealType mealType;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "total_kcal", nullable = false)
    private Integer totalKcal;

    @Builder
    private DietMeal(DietPlan plan, MealType mealType, Integer totalKcal) {
        this.plan = plan;
        this.mealType = mealType;
        this.totalKcal = totalKcal;
    }

    public enum MealType { breakfast, lunch, dinner, snack }
}
