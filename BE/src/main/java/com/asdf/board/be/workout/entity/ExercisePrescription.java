package com.asdf.board.be.workout.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.enums.ExperienceLevel;
import java.io.Serializable;
import lombok.AccessLevel;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "exercise_prescriptions")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ExercisePrescription {

    @EmbeddedId
    @Setter(AccessLevel.NONE)
    private Key id;

    @MapsId("exerciseId")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "exercise_id")
    private Exercise exercise;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "min_sets", nullable = false)
    private Integer minSets;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "max_sets", nullable = false)
    private Integer maxSets;

    @Builder
    private ExercisePrescription(Exercise exercise, ExperienceLevel experienceLevel, Integer minSets, Integer maxSets) {
        this.id = new Key();
        this.exercise = exercise;
        this.id.setExperienceLevel(experienceLevel);
        this.minSets = minSets;
        this.maxSets = maxSets;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @EqualsAndHashCode
    @Embeddable
    public static class Key implements Serializable {

        @Column(name = "exercise_id")
        private Long exerciseId;

        @Enumerated(EnumType.STRING)
        @Column(name = "experience_level", nullable = false, length = 10)
        private ExperienceLevel experienceLevel;
    }
}
