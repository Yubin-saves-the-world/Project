package com.asdf.board.be.partner.repository;

import com.asdf.board.be.partner.entity.UserCoupon;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserCouponRepository extends JpaRepository<UserCoupon, Long> {

    @Query("select c from UserCoupon c join fetch c.coupon cp join fetch cp.partner where c.user.id = :userId order by c.id desc")
    List<UserCoupon> findAllOfUser(@Param("userId") Long userId);

    @Query("select c from UserCoupon c join fetch c.coupon cp join fetch cp.partner where c.id = :id and c.user.id = :userId")
    Optional<UserCoupon> findOfUser(@Param("id") Long id, @Param("userId") Long userId);

    boolean existsByUserMissionId(Long userMissionId);
}
