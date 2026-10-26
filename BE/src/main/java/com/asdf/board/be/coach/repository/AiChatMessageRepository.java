package com.asdf.board.be.coach.repository;

import com.asdf.board.be.coach.entity.AiChatMessage;
import java.time.LocalDateTime;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AiChatMessageRepository extends JpaRepository<AiChatMessage, Long> {

    Page<AiChatMessage> findByUserId(Long userId, Pageable pageable);

    long countByUserIdAndRoleAndCreatedAtGreaterThanEqual(Long userId, AiChatMessage.Role role, LocalDateTime from);
}
