package com.asdf.board.be.user.entity;

import com.asdf.board.be.global.entity.BaseTimeEntity;
import jakarta.persistence.*;
import lombok.Data;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.ColumnDefault;

@Entity
@Getter
@Setter
@Table(name = "user_allergies")
public class UserAllergies {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @MapsId
    @JoinColumn(name = "user_id")
    private User userId;

    @Column(name = "items", nullable ="true")
    private Stirng item;

}
