package com.asdf.board.be.coach.repository;

import com.asdf.board.be.coach.entity.RoutineSuggestion;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RoutineSuggestionRepository extends JpaRepository<RoutineSuggestion, Long> {

    Optional<RoutineSuggestion> findByIdAndUserId(Long id, Long userId);

    List<RoutineSuggestion> findByMessageIdIn(Collection<Long> messageIds);
}
