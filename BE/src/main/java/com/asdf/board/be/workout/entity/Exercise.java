package com.asdf.board.be.workout.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import com.asdf.board.be.global.enums.TargetPart;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "exercises")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Exercise extends BaseCreatedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "exercise_id")
    private Long id;

    @Column(name = "name", nullable = false, unique = true, length = 50)
    private String name;

    @Column(name = "name_nospace", insertable = false, updatable = false, length = 50)
    @Setter(AccessLevel.NONE)
    private String nameNospace;

    @Enumerated(EnumType.STRING)
    @Column(name = "target_part", nullable = false, length = 10)
    private TargetPart targetPart;

    @Enumerated(EnumType.STRING)
    @Column(name = "equipment", nullable = false, length = 10)
    private Equipment equipment;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "difficulty", nullable = false)
    private Integer difficulty;

    @Column(name = "description", columnDefinition = "text")
    private String description;

    @Column(name = "media_url", length = 500)
    private String mediaUrl;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive;

    @Builder
    private Exercise(String name, TargetPart targetPart, Equipment equipment, Integer difficulty, String description, String mediaUrl, Boolean isActive) {
        this.name = name;
        this.targetPart = targetPart;
        this.equipment = equipment;
        this.difficulty = difficulty;
        this.description = description;
        this.mediaUrl = mediaUrl;
        this.isActive = isActive != null ? isActive : true;
    }

    public enum Equipment { barbell, dumbbell, machine, bodyweight }
}
