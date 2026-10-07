package com.asdf.board.be.coach.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import com.asdf.board.be.user.entity.User;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "routine_suggestions")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class RoutineSuggestion extends BaseCreatedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "suggestion_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "message_id", nullable = false)
    private AiChatMessage message;

    @Column(name = "summary", nullable = false, length = 100)
    private String summary;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "changes_json", nullable = false, columnDefinition = "json")
    private String changesJson;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 10)
    private Status status;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "handled_at")
    private LocalDateTime handledAt;

    @Builder
    private RoutineSuggestion(User user, AiChatMessage message, String summary, String changesJson, Status status, LocalDateTime expiresAt, LocalDateTime handledAt) {
        this.user = user;
        this.message = message;
        this.summary = summary;
        this.changesJson = changesJson;
        this.status = status != null ? status : Status.pending;
        this.expiresAt = expiresAt;
        this.handledAt = handledAt;
    }

    public enum Status { pending, applied, dismissed }
}
