package com.asdf.board.be.partner.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "coupons")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Coupon {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "coupon_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "partner_id", nullable = false)
    private Partner partner;

    @Column(name = "title", nullable = false, length = 50)
    private String title;

    @Column(name = "discount_desc", nullable = false, length = 100)
    private String discountDesc;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "valid_days", nullable = false)
    private Integer validDays;

    @Builder
    private Coupon(Partner partner, String title, String discountDesc, Integer validDays) {
        this.partner = partner;
        this.title = title;
        this.discountDesc = discountDesc;
        this.validDays = validDays;
    }
}
