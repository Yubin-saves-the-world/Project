package com.asdf.board.be.partner.repository;

import com.asdf.board.be.partner.entity.Mission;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MissionRepository extends JpaRepository<Mission, Long> {

    @EntityGraph(attributePaths = "coupon")
    Optional<Mission> findFirstByIsActiveTrueOrderByIdDesc();
}
