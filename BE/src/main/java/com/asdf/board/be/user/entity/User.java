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
@Table(name = "users")
public class User extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(length = 255, unique = true, nullable = false)
    private String email;

    @Column(name = "password_hash", length = 255, unique = true)
    private String password_hash;

    @Column(length = 50, nullable = false)
    private String nickname;


    @Enumerated(EnumType.STRING)
    @ColumnDefault("'email'")
    @Column(length = 20, nullable = false)
    private EnumAll.Provider provider;

    @Column(nullable = false, length = 255)
    private Long provider_id;


    @Enumerated(EnumType.STRING)
    @Column(nullable = false, name = "survey_status")
    private EnumAll.SurveyStatus surveyStatus;


    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @ColumnDefault("'USER'")
    private EnumAll.Role role;



    @OneToOne(mappedBy = "user", casscade = CascadeType.ALL)
    private UserProfiles profile;

    @OneToOne(mappedBy = "e")



}
