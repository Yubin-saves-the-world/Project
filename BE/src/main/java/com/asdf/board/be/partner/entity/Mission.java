package com.asdf.board.be.partner.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "missions")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Mission extends BaseCreatedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "mission_id")
    private Long id;

    @Column(name = "title", nullable = false, length = 50)
    private String title;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "condition_json", nullable = false, columnDefinition = "json")
    private String conditionJson;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "period_days", nullable = false)
    private Integer periodDays;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "coupon_id")
    private Coupon coupon;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive;

    @Builder
    private Mission(String title, String conditionJson, Integer periodDays, Coupon coupon, Boolean isActive) {
        this.title = title;
        this.conditionJson = conditionJson;
        this.periodDays = periodDays;
        this.coupon = coupon;
        this.isActive = isActive != null ? isActive : true;
    }
}
