package com.asdf.board.be.user.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseTimeEntity;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.Builder;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "user_id")
    private Long id;

    @Column(name = "email", unique = true, length = 255)
    private String email;

    @Column(name = "password_hash", length = 60)
    private String passwordHash;

    @Column(name = "nickname", nullable = false, unique = true, length = 30)
    private String nickname;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 10)
    private Role role;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 10)
    private Status status;

    @Enumerated(EnumType.STRING)
    @Column(name = "auth_provider", nullable = false, length = 10)
    private AuthProvider authProvider;

    @Column(name = "google_sub", unique = true, length = 64)
    private String googleSub;

    @Column(name = "kakao_id", unique = true)
    private Long kakaoId;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    @Builder
    private User(String email, String passwordHash, String nickname, Role role, Status status, AuthProvider authProvider, String googleSub, Long kakaoId, LocalDateTime deletedAt) {
        this.email = email;
        this.passwordHash = passwordHash;
        this.nickname = nickname;
        this.role = role != null ? role : Role.user;
        this.status = status != null ? status : Status.active;
        this.authProvider = authProvider != null ? authProvider : AuthProvider.email;
        this.googleSub = googleSub;
        this.kakaoId = kakaoId;
        this.deletedAt = deletedAt;
    }

    public enum Role { user, admin }

    public enum Status { active, withdrawn }

    public enum AuthProvider { email, google, kakao }
}
