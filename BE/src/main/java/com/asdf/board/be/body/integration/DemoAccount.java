package com.asdf.board.be.body.integration;

import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.user.entity.*;
import com.asdf.board.be.user.repository.*;
import java.math.BigDecimal;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
@Profile("demo")
public class DemoAccount implements CommandLineRunner {
  private final UserRepository users;
  private final UserProfileRepository profiles;
  private final UserConsentRepository consents;
  private final PasswordEncoder encoder;
  private final String password;

  public DemoAccount(
      UserRepository u,
      UserProfileRepository p,
      UserConsentRepository c,
      PasswordEncoder e,
      @Value("${DEMO_PASSWORD:movid1234}") String pass) {
    users = u;
    profiles = p;
    consents = c;
    encoder = e;
    password = pass;
  }

  @Override
  @Transactional
  public void run(String... args) {
    var existing = users.findByEmail("demo@movid.local");
    if (existing.isPresent()) {
      existing.get().setRole(User.Role.admin);
      users.save(existing.get());
      return;
    }
    User user =
        users.save(
            User.builder()
                .email("demo@movid.local")
                .role(User.Role.admin)
                .nickname("MOVID연동시연")
                .passwordHash(encoder.encode(password))
                .build());
    profiles.save(
        UserProfile.builder()
            .user(user)
            .heightCm(new BigDecimal("170.0"))
            .weightKg(new BigDecimal("65.0"))
            .age(20)
            .gender(UserProfile.Gender.none)
            .goalType(UserProfile.GoalType.posture)
            .weeklyFrequency(3)
            .experienceLevel(ExperienceLevel.under3m)
            .build());
    for (var type : UserConsent.ConsentType.values())
      consents.save(
          UserConsent.builder()
              .user(user)
              .consentType(type)
              .agreed(true)
              .policyVersion("demo-local-only")
              .source(UserConsent.Source.signup)
              .build());
  }
}
