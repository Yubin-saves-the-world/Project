package com.asdf.board.be.diet.entity;

import jakarta.persistence.*;
import com.asdf.board.be.body.entity.BodyAnalysis;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import com.asdf.board.be.user.entity.User;
import java.time.LocalDate;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "diet_plans", uniqueConstraints = {@UniqueConstraint(name = "uq_diet_day", columnNames = {"user_id", "plan_date"})})
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class DietPlan extends BaseCreatedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "plan_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "analysis_id", nullable = false)
    private BodyAnalysis analysis;

    @Column(name = "plan_date", nullable = false)
    private LocalDate planDate;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "target_kcal", nullable = false)
    private Integer targetKcal;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "carb_g", nullable = false)
    private Integer carbG;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "protein_g", nullable = false)
    private Integer proteinG;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "fat_g", nullable = false)
    private Integer fatG;

    @Builder
    private DietPlan(User user, BodyAnalysis analysis, LocalDate planDate, Integer targetKcal, Integer carbG, Integer proteinG, Integer fatG) {
        this.user = user;
        this.analysis = analysis;
        this.planDate = planDate;
        this.targetKcal = targetKcal;
        this.carbG = carbG;
        this.proteinG = proteinG;
        this.fatG = fatG;
    }
}
