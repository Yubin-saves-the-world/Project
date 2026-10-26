package com.asdf.board.be.user.repository;

import com.asdf.board.be.user.entity.UserAllergy;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserAllergyRepository extends JpaRepository<UserAllergy, Long> {

    List<UserAllergy> findByUserIdOrderByIdAsc(Long userId);

    Optional<UserAllergy> findByIdAndUserId(Long id, Long userId);
}
