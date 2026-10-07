package com.asdf.board.be.partner.entity;

import jakarta.persistence.*;
import com.asdf.board.be.user.entity.User;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.Builder;

@Entity
@Table(name = "user_missions", uniqueConstraints = {@UniqueConstraint(name = "uq_user_mission", columnNames = {"user_id", "mission_id", "started_at"})})
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserMission {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "user_mission_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "mission_id", nullable = false)
    private Mission mission;

    @Column(name = "started_at", nullable = false)
    private LocalDateTime startedAt;

    @Column(name = "ends_at", nullable = false)
    private LocalDateTime endsAt;

    @Column(name = "progress_count", nullable = false)
    private Integer progressCount;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    @Builder
    private UserMission(User user, Mission mission, LocalDateTime startedAt, LocalDateTime endsAt, Integer progressCount, LocalDateTime completedAt) {
        this.user = user;
        this.mission = mission;
        this.startedAt = startedAt;
        this.endsAt = endsAt;
        this.progressCount = progressCount != null ? progressCount : 0;
        this.completedAt = completedAt;
    }
}
