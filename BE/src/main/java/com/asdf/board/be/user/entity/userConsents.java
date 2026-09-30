package com.asdf.board.be.user.entity;


import jakarta.persistence.*;
import lombok.Data;

@Entity
@Data
@Table(name = "user_consents")
public class userConsents {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)


}
