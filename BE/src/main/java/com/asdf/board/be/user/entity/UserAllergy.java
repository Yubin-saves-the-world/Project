package com.asdf.board.be.user.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.Builder;

@Entity
@Table(name = "user_allergies", uniqueConstraints = {@UniqueConstraint(name = "uq_allergy_item", columnNames = {"user_id", "item"})})
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserAllergy extends BaseCreatedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "allergy_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "item", nullable = false, length = 50)
    private String item;

    @Builder
    private UserAllergy(User user, String item) {
        this.user = user;
        this.item = item;
    }
}
