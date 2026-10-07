package com.asdf.board.be.notification.entity;

import jakarta.persistence.*;
import com.asdf.board.be.user.entity.User;
import java.io.Serializable;
import java.time.LocalTime;
import lombok.AccessLevel;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.Builder;

@Entity
@Table(name = "notification_settings")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class NotificationSetting {

    @EmbeddedId
    @Setter(AccessLevel.NONE)
    private Key id;

    @MapsId("userId")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(name = "enabled", nullable = false)
    private Boolean enabled;

    @Column(name = "notify_time")
    private LocalTime notifyTime;

    @Builder
    private NotificationSetting(User user, Type type, Boolean enabled, LocalTime notifyTime) {
        this.id = new Key();
        this.user = user;
        this.id.setType(type);
        this.enabled = enabled != null ? enabled : true;
        this.notifyTime = notifyTime;
    }

    public enum Type { workout, diet, streak_risk }

    @Getter
    @Setter
    @NoArgsConstructor
    @EqualsAndHashCode
    @Embeddable
    public static class Key implements Serializable {

        @Column(name = "user_id")
        private Long userId;

        @Enumerated(EnumType.STRING)
        @Column(name = "type", nullable = false, length = 12)
        private Type type;
    }
}
