package com.asdf.board.be.coach.repository;

import com.asdf.board.be.coach.entity.AiChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AiChatMessageRepository extends JpaRepository<AiChatMessage, Long> {
    List<AiChatMessage> findTop20ByUser_IdOrderByCreatedAtAsc(Long userId);
}
