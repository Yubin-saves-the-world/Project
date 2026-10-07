package com.asdf.board.be.diet.entity;

import jakarta.persistence.*;
import com.asdf.board.be.partner.entity.Product;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "diet_items")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class DietItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "diet_item_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "meal_id", nullable = false)
    private DietMeal meal;

    @Column(name = "food_name", nullable = false, length = 50)
    private String foodName;

    @Column(name = "amount", nullable = false, length = 30)
    private String amount;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "kcal", nullable = false)
    private Integer kcal;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "product_id")
    private Product product;

    @Builder
    private DietItem(DietMeal meal, String foodName, String amount, Integer kcal, Product product) {
        this.meal = meal;
        this.foodName = foodName;
        this.amount = amount;
        this.kcal = kcal;
        this.product = product;
    }
}
