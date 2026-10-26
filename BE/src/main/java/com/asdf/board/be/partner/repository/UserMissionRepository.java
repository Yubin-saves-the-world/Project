package com.asdf.board.be.partner.repository;

import com.asdf.board.be.partner.entity.UserMission;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserMissionRepository extends JpaRepository<UserMission, Long> {

    Optional<UserMission> findFirstByUserIdAndMissionIdOrderByIdDesc(Long userId, Long missionId);
}
