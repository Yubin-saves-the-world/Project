package com.asdf.board.be.community.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import com.asdf.board.be.user.entity.User;
import java.io.Serializable;
import lombok.AccessLevel;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.Builder;

@Entity
@Table(name = "post_likes")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PostLike extends BaseCreatedEntity {

    @EmbeddedId
    @Setter(AccessLevel.NONE)
    private Key id;

    @MapsId("postId")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id")
    private Post post;

    @MapsId("userId")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Builder
    private PostLike(Post post, User user) {
        this.id = new Key();
        this.post = post;
        this.user = user;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @EqualsAndHashCode
    @Embeddable
    public static class Key implements Serializable {

        @Column(name = "post_id")
        private Long postId;

        @Column(name = "user_id")
        private Long userId;
    }
}
