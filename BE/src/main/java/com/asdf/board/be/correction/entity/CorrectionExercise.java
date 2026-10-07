package com.asdf.board.be.correction.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.Builder;

@Entity
@Table(name = "correction_exercises")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CorrectionExercise {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "correction_id")
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(name = "target_issue", nullable = false, length = 20)
    private TargetIssue targetIssue;

    @Column(name = "name", nullable = false, length = 50)
    private String name;

    @Column(name = "method", nullable = false, columnDefinition = "text")
    private String method;

    @Column(name = "duration_or_reps", nullable = false, length = 30)
    private String durationOrReps;

    @Column(name = "media_url", length = 500)
    private String mediaUrl;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive;

    @Builder
    private CorrectionExercise(TargetIssue targetIssue, String name, String method, String durationOrReps, String mediaUrl, Boolean isActive) {
        this.targetIssue = targetIssue;
        this.name = name;
        this.method = method;
        this.durationOrReps = durationOrReps;
        this.mediaUrl = mediaUrl;
        this.isActive = isActive != null ? isActive : true;
    }

    public enum TargetIssue { shoulder_tilt, pelvis_tilt, neck_forward }
}
