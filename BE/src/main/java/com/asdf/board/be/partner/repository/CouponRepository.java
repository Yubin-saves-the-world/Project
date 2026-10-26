package com.asdf.board.be.partner.repository;

import com.asdf.board.be.partner.entity.Coupon;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CouponRepository extends JpaRepository<Coupon, Long> {
}
