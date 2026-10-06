package com.asdf.board.be.coach.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import com.asdf.board.be.user.entity.User;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.Builder;

@Entity
@Table(name = "ai_chat_messages")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AiChatMessage extends BaseCreatedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "message_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, length = 10)
    private Role role;

    @Column(name = "content", nullable = false, columnDefinition = "text")
    private String content;

    @Builder
    private AiChatMessage(User user, Role role, String content) {
        this.user = user;
        this.role = role;
        this.content = content;
    }

    public enum Role { user, assistant }
}
