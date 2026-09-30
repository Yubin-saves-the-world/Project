package com.asdf.board.be.user.entity;


import jakarta.persistence.*;
import lombok.Data;

@Entity
@Data
@Table(name = "user_consents")
public class userConsents extends BaseTimeEntity{

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @MapsId
    @JoinColumn(name = "user_id")
    private User userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, name = "consent_type")
    private EnumAll.ConsentType consentType;

    @Column(nullable = false)
    private boolean agreed;

//   agreed_at



}
