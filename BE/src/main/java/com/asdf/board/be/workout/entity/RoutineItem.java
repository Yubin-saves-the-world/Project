package com.asdf.board.be.workout.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "routine_items", uniqueConstraints = {@UniqueConstraint(name = "uq_item_order", columnNames = {"routine_id", "order_no"}), @UniqueConstraint(name = "uq_item_exercise", columnNames = {"routine_id", "exercise_id"})})
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class RoutineItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "item_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "routine_id", nullable = false)
    private Routine routine;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "exercise_id", nullable = false)
    private Exercise exercise;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "order_no", nullable = false)
    private Integer orderNo;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "target_sets", nullable = false)
    private Integer targetSets;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "target_reps", nullable = false)
    private Integer targetReps;

    @Column(name = "target_weight_kg", precision = 5, scale = 1)
    private BigDecimal targetWeightKg;

    @Column(name = "reason", length = 200)
    private String reason;

    @Builder
    private RoutineItem(Routine routine, Exercise exercise, Integer orderNo, Integer targetSets, Integer targetReps, BigDecimal targetWeightKg, String reason) {
        this.routine = routine;
        this.exercise = exercise;
        this.orderNo = orderNo;
        this.targetSets = targetSets;
        this.targetReps = targetReps;
        this.targetWeightKg = targetWeightKg;
        this.reason = reason;
    }
}
