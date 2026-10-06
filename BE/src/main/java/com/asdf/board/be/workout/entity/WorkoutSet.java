package com.asdf.board.be.workout.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseTimeEntity;
import java.math.BigDecimal;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "workout_sets", uniqueConstraints = {@UniqueConstraint(name = "uq_set_client", columnNames = {"log_id", "client_set_id"}), @UniqueConstraint(name = "uq_set_no", columnNames = {"log_id", "set_no"})})
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WorkoutSet extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "set_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "log_id", nullable = false)
    private WorkoutLog log;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "client_set_id", nullable = false, length = 36)
    private String clientSetId;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "set_no", nullable = false)
    private Integer setNo;

    @Column(name = "weight_kg", nullable = false, precision = 5, scale = 1)
    private BigDecimal weightKg;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "reps", nullable = false)
    private Integer reps;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "rest_sec")
    private Integer restSec;

    @Column(name = "is_done", nullable = false)
    private Boolean isDone;

    @Column(name = "version", nullable = false)
    private Integer version;

    @Builder
    private WorkoutSet(WorkoutLog log, String clientSetId, Integer setNo, BigDecimal weightKg, Integer reps, Integer restSec, Boolean isDone, Integer version) {
        this.log = log;
        this.clientSetId = clientSetId;
        this.setNo = setNo;
        this.weightKg = weightKg;
        this.reps = reps;
        this.restSec = restSec;
        this.isDone = isDone != null ? isDone : true;
        this.version = version != null ? version : 1;
    }
}
