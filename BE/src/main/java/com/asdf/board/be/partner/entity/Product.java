package com.asdf.board.be.partner.entity;

import jakarta.persistence.*;
import com.asdf.board.be.global.entity.BaseCreatedEntity;
import java.time.LocalDate;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "products")
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Product extends BaseCreatedEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "product_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "partner_id", nullable = false)
    private Partner partner;

    @Enumerated(EnumType.STRING)
    @Column(name = "category", nullable = false, length = 12)
    private Category category;

    @Column(name = "name", nullable = false, length = 100)
    private String name;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "kcal")
    private Integer kcal;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "carb_g")
    private Integer carbG;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "protein_g")
    private Integer proteinG;

    @JdbcTypeCode(SqlTypes.SMALLINT)
    @Column(name = "fat_g")
    private Integer fatG;

    @Column(name = "price")
    private Integer price;

    @Column(name = "link_url", nullable = false, length = 500)
    private String linkUrl;

    @Column(name = "display_from", nullable = false)
    private LocalDate displayFrom;

    @Column(name = "display_to", nullable = false)
    private LocalDate displayTo;

    @Column(name = "is_ad_labeled", nullable = false)
    private Boolean isAdLabeled;

    @Builder
    private Product(Partner partner, Category category, String name, Integer kcal, Integer carbG, Integer proteinG, Integer fatG, Integer price, String linkUrl, LocalDate displayFrom, LocalDate displayTo, Boolean isAdLabeled) {
        this.partner = partner;
        this.category = category;
        this.name = name;
        this.kcal = kcal;
        this.carbG = carbG;
        this.proteinG = proteinG;
        this.fatG = fatG;
        this.price = price;
        this.linkUrl = linkUrl;
        this.displayFrom = displayFrom;
        this.displayTo = displayTo;
        this.isAdLabeled = isAdLabeled != null ? isAdLabeled : true;
    }

    public enum Category { food, supplement, equipment }
}
