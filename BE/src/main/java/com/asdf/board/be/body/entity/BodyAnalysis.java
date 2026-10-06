package com.asdf.board.be.body.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import com.asdf.board.be.user.entity.User;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "body_analyses", uniqueConstraints = {@UniqueConstraint(name = "uq_analysis_one_pending", columnNames = {"user_id", "pending_key"})})
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class BodyAnalysis extends BaseCreatedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "analysis_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "source", nullable = false, length = 10)
    private Source source;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 10)
    private Status status;

    @Enumerated(EnumType.STRING)
    @Column(name = "error_code", length = 20)
    private ErrorCode errorCode;

    @Column(name = "error_message", length = 100)
    private String errorMessage;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "photo_id")
    private Photo photo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "side_photo_id")
    private Photo sidePhoto;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "goal_body_id")
    private GoalBody goalBody;

    @Column(name = "text_input", length = 500)
    private String textInput;

    @Column(name = "shoulder_tilt_deg", precision = 4, scale = 1)
    private BigDecimal shoulderTiltDeg;

    @Column(name = "pelvis_tilt_deg", precision = 4, scale = 1)
    private BigDecimal pelvisTiltDeg;

    @Column(name = "neck_forward_deg", precision = 4, scale = 1)
    private BigDecimal neckForwardDeg;

    @Column(name = "shoulder_hip_ratio", precision = 4, scale = 2)
    private BigDecimal shoulderHipRatio;

    @Column(name = "torso_leg_ratio", precision = 4, scale = 2)
    private BigDecimal torsoLegRatio;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "unavailable_json", columnDefinition = "json")
    private String unavailableJson;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "balance_score")
    private Integer balanceScore;

    @Column(name = "measurement_version", length = 20)
    private String measurementVersion;

    @Column(name = "body_type", length = 10)
    private String bodyType;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "judgements_json", columnDefinition = "json")
    private String judgementsJson;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "priority_parts_json", columnDefinition = "json")
    private String priorityPartsJson;

    @Column(name = "comparison_summary", length = 100)
    private String comparisonSummary;

    @Column(name = "comparison_detail", length = 500)
    private String comparisonDetail;

    @Column(name = "text_summary", length = 500)
    private String textSummary;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "pending_key", insertable = false, updatable = false)
    @Setter(AccessLevel.NONE)
    private Integer pendingKey;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    @Builder
    private BodyAnalysis(User user, Source source, Status status, ErrorCode errorCode, String errorMessage, Photo photo, Photo sidePhoto, GoalBody goalBody, String textInput, BigDecimal shoulderTiltDeg, BigDecimal pelvisTiltDeg, BigDecimal neckForwardDeg, BigDecimal shoulderHipRatio, BigDecimal torsoLegRatio, String unavailableJson, Integer balanceScore, String measurementVersion, String bodyType, String judgementsJson, String priorityPartsJson, String comparisonSummary, String comparisonDetail, String textSummary, LocalDateTime completedAt) {
        this.user = user;
        this.source = source != null ? source : Source.photo;
        this.status = status != null ? status : Status.pending;
        this.errorCode = errorCode;
        this.errorMessage = errorMessage;
        this.photo = photo;
        this.sidePhoto = sidePhoto;
        this.goalBody = goalBody;
        this.textInput = textInput;
        this.shoulderTiltDeg = shoulderTiltDeg;
        this.pelvisTiltDeg = pelvisTiltDeg;
        this.neckForwardDeg = neckForwardDeg;
        this.shoulderHipRatio = shoulderHipRatio;
        this.torsoLegRatio = torsoLegRatio;
        this.unavailableJson = unavailableJson;
        this.balanceScore = balanceScore;
        this.measurementVersion = measurementVersion;
        this.bodyType = bodyType;
        this.judgementsJson = judgementsJson;
        this.priorityPartsJson = priorityPartsJson;
        this.comparisonSummary = comparisonSummary;
        this.comparisonDetail = comparisonDetail;
        this.textSummary = textSummary;
        this.completedAt = completedAt;
    }

    public enum Source { photo, text }

    public enum Status { pending, done, failed }

    public enum ErrorCode { IMAGE_BLURRY, NO_PERSON, MULTIPLE_PEOPLE, NOT_FULL_BODY, NOT_FRONTAL, AI_FAILED, AI_TIMEOUT }
}
