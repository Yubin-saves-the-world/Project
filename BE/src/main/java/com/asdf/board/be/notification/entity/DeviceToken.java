package com.asdf.board.be.notification.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseTimeEntity;
import com.asdf.board.be.user.entity.User;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.Builder;

@Entity
@Table(name = "device_tokens", uniqueConstraints = {@UniqueConstraint(name = "uq_device_platform", columnNames = {"user_id", "platform"})})
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class DeviceToken extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "token_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "fcm_token", nullable = false, unique = true, length = 255)
    private String fcmToken;

    @Enumerated(EnumType.STRING)
    @Column(name = "platform", nullable = false, length = 10)
    private Platform platform;

    @Builder
    private DeviceToken(User user, String fcmToken, Platform platform) {
        this.user = user;
        this.fcmToken = fcmToken;
        this.platform = platform;
    }

    public enum Platform { android, ios }
}
