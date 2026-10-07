package com.asdf.board.be.partner.entity;

import jakarta.persistence.*;
import com.asdf.board.be.user.entity.User;
import java.time.LocalDate;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import lombok.Builder;

@Entity
@Table(name = "user_coupons")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserCoupon {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "user_coupon_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "coupon_id", nullable = false)
    private Coupon coupon;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_mission_id")
    private UserMission userMission;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 10)
    private Status status;

    @Column(name = "valid_until", nullable = false)
    private LocalDate validUntil;

    @CreationTimestamp
    @Column(name = "issued_at", nullable = false, updatable = false)
    private LocalDateTime issuedAt;

    @Column(name = "used_at")
    private LocalDateTime usedAt;

    @Builder
    private UserCoupon(User user, Coupon coupon, UserMission userMission, Status status, LocalDate validUntil, LocalDateTime usedAt) {
        this.user = user;
        this.coupon = coupon;
        this.userMission = userMission;
        this.status = status != null ? status : Status.available;
        this.validUntil = validUntil;
        this.usedAt = usedAt;
    }

    public enum Status { available, used, expired }
}
