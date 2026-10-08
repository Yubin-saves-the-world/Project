package com.asdf.board.be.user.repository;

import com.asdf.board.be.user.entity.UserConsent;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserConsentRepository extends JpaRepository<UserConsent, Long> {

    List<UserConsent> findByUserIdOrderByIdAsc(Long userId);
}
