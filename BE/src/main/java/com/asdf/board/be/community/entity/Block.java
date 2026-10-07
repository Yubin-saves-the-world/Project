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
@Table(name = "blocks")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Block extends BaseCreatedEntity {

    @EmbeddedId
    @Setter(AccessLevel.NONE)
    private Key id;

    @MapsId("blockerId")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "blocker_id")
    private User blocker;

    @MapsId("blockedId")
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "blocked_id")
    private User blocked;

    @Builder
    private Block(User blocker, User blocked) {
        this.id = new Key();
        this.blocker = blocker;
        this.blocked = blocked;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @EqualsAndHashCode
    @Embeddable
    public static class Key implements Serializable {

        @Column(name = "blocker_id")
        private Long blockerId;

        @Column(name = "blocked_id")
        private Long blockedId;
    }
}
