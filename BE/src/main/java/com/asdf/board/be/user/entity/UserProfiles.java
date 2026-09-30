package com.asdf.board.be.user.entity;


import com.asdf.board.be.global.entity.BaseTimeEntity;
import jakarta.persistence.*;
import lombok.Data;

import java.math.BigDecimal;

@Entity
@Data
@Table(name = "user_profiles")
public class UserProfiles extends BaseTimeEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @MapsId
    @JoinColumn(name = "user_id")
    private User user;

    @Column(nullable = false, name = "height_cm", precision = 5, scale = 1)
    private BigDecimal height;

    @Column(nullable = false, name = "weight_cm", precision = 5, scale = 1)
    private BigDecimal weight;

    private Byte age;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private EnumAll.Gender gender;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, name = "goal_type")
    private EnumAll.Goal goal;

    @Column(name = "weekly_frequency")
    private Byte WeeklyFrequency;

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    private EnumAll.ExperienceLevel experienceLevel;

    // updatedAt은 BaseTimeOnly 클래스를 상속했으므로 사용하지 않아도된.

}
