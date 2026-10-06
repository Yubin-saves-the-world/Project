package com.asdf.board.be.user.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import lombok.Builder;

@Entity
@Table(name = "user_consents")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserConsent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "consent_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "consent_type", nullable = false, length = 20)
    private ConsentType consentType;

    @Column(name = "agreed", nullable = false)
    private Boolean agreed;

    @Column(name = "policy_version", nullable = false, length = 30)
    private String policyVersion;

    @Enumerated(EnumType.STRING)
    @Column(name = "source", nullable = false, length = 10)
    private Source source;

    @CreationTimestamp
    @Column(name = "agreed_at", nullable = false, updatable = false)
    private LocalDateTime agreedAt;

    @Builder
    private UserConsent(User user, ConsentType consentType, Boolean agreed, String policyVersion, Source source) {
        this.user = user;
        this.consentType = consentType;
        this.agreed = agreed;
        this.policyVersion = policyVersion;
        this.source = source;
    }

    public enum ConsentType { terms, privacy, body_photo, ai_processing }

    public enum Source { signup, settings, google, kakao }
}
