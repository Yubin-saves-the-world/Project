package com.asdf.board.be.partner.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import java.time.LocalDate;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import lombok.Builder;

@Entity
@Table(name = "partners")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Partner extends BaseCreatedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "partner_id")
    private Long id;

    @Column(name = "name", nullable = false, length = 50)
    private String name;

    @Column(name = "contract_start", nullable = false)
    private LocalDate contractStart;

    @Column(name = "contract_end", nullable = false)
    private LocalDate contractEnd;

    @Builder
    private Partner(String name, LocalDate contractStart, LocalDate contractEnd) {
        this.name = name;
        this.contractStart = contractStart;
        this.contractEnd = contractEnd;
    }
}
