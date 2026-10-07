package com.asdf.board.be.user.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.enums.ExperienceLevel;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "user_profiles")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "profile_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "height_cm", nullable = false, precision = 4, scale = 1)
    private BigDecimal heightCm;

    @Column(name = "weight_kg", nullable = false, precision = 4, scale = 1)
    private BigDecimal weightKg;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "age", nullable = false)
    private Integer age;

    @Enumerated(EnumType.STRING)
    @Column(name = "gender", nullable = false, length = 6)
    private Gender gender;

    @Enumerated(EnumType.STRING)
    @Column(name = "goal_type", nullable = false, length = 10)
    private GoalType goalType;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "weekly_frequency", nullable = false)
    private Integer weeklyFrequency;

    @Enumerated(EnumType.STRING)
    @Column(name = "experience_level", nullable = false, length = 10)
    private ExperienceLevel experienceLevel;

    @CreationTimestamp
    @Column(name = "measured_at", nullable = false, updatable = false)
    private LocalDateTime measuredAt;

    @Builder
    private UserProfile(User user, BigDecimal heightCm, BigDecimal weightKg, Integer age, Gender gender, GoalType goalType, Integer weeklyFrequency, ExperienceLevel experienceLevel) {
        this.user = user;
        this.heightCm = heightCm;
        this.weightKg = weightKg;
        this.age = age;
        this.gender = gender != null ? gender : Gender.none;
        this.goalType = goalType;
        this.weeklyFrequency = weeklyFrequency;
        this.experienceLevel = experienceLevel;
    }

    public enum Gender { male, female, none }

    public enum GoalType { muscle, diet, posture }
}
