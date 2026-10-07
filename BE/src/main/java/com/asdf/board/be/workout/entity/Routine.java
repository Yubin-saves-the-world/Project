package com.asdf.board.be.workout.entity;

import jakarta.persistence.*;
import com.asdf.board.be.body.entity.BodyAnalysis;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import com.asdf.board.be.global.enums.TargetPart;
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
@Table(name = "routines", uniqueConstraints = {@UniqueConstraint(name = "uq_routine_day", columnNames = {"user_id", "scheduled_date"})})
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Routine extends BaseCreatedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "routine_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "analysis_id", nullable = false)
    private BodyAnalysis analysis;

    @Column(name = "scheduled_date", nullable = false)
    private LocalDate scheduledDate;

    @Column(name = "title", nullable = false, length = 50)
    private String title;

    @Enumerated(EnumType.STRING)
    @Column(name = "target_part", nullable = false, length = 10)
    private TargetPart targetPart;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "estimated_minutes", nullable = false)
    private Integer estimatedMinutes;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 10)
    private Status status;

    @Builder
    private Routine(User user, BodyAnalysis analysis, LocalDate scheduledDate, String title, TargetPart targetPart, Integer estimatedMinutes, Status status) {
        this.user = user;
        this.analysis = analysis;
        this.scheduledDate = scheduledDate;
        this.title = title;
        this.targetPart = targetPart;
        this.estimatedMinutes = estimatedMinutes;
        this.status = status != null ? status : Status.planned;
    }

    public enum Status { planned, done, skipped }
}
