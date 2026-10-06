package com.asdf.board.be.workout.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import com.asdf.board.be.user.entity.User;
import java.time.LocalDate;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.Builder;

@Entity
@Table(name = "workout_logs", uniqueConstraints = {@UniqueConstraint(name = "uq_log_one_active", columnNames = {"user_id", "active_exercise_id"})})
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WorkoutLog extends BaseCreatedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "log_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "exercise_id", nullable = false)
    private Exercise exercise;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "routine_id")
    private Routine routine;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 12)
    private Status status;

    @Column(name = "workout_date", nullable = false)
    private LocalDate workoutDate;

    @Column(name = "started_at", nullable = false)
    private LocalDateTime startedAt;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    @Column(name = "duration_sec")
    private Integer durationSec;

    @Column(name = "memo", length = 500)
    private String memo;

    @Column(name = "active_exercise_id", insertable = false, updatable = false)
    @Setter(AccessLevel.NONE)
    private Long activeExerciseId;

    @Builder
    private WorkoutLog(User user, Exercise exercise, Routine routine, Status status, LocalDate workoutDate, LocalDateTime startedAt, LocalDateTime completedAt, Integer durationSec, String memo) {
        this.user = user;
        this.exercise = exercise;
        this.routine = routine;
        this.status = status != null ? status : Status.in_progress;
        this.workoutDate = workoutDate;
        this.startedAt = startedAt;
        this.completedAt = completedAt;
        this.durationSec = durationSec;
        this.memo = memo;
    }

    public enum Status { in_progress, completed, aborted }
}
