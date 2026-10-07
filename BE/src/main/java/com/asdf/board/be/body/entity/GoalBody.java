package com.asdf.board.be.body.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseTimeEntity;
import com.asdf.board.be.user.entity.User;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.Builder;

@Entity
@Table(name = "goal_bodies")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class GoalBody extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "goal_body_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 10)
    private Status status;

    @Column(name = "description", length = 200)
    private String description;

    @Column(name = "summary", length = 500)
    private String summary;

    @Column(name = "error_message", length = 100)
    private String errorMessage;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "source_photo_id")
    private Photo sourcePhoto;

    @Builder
    private GoalBody(User user, Status status, String description, String summary, String errorMessage, Photo sourcePhoto) {
        this.user = user;
        this.status = status;
        this.description = description;
        this.summary = summary;
        this.errorMessage = errorMessage;
        this.sourcePhoto = sourcePhoto;
    }

    public enum Status { pending, done, failed }
}
