package com.asdf.board.be.community.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import lombok.Builder;

@Entity
@Table(name = "post_images", uniqueConstraints = {@UniqueConstraint(name = "uq_image_order", columnNames = {"post_id", "order_no"})})
@Getter
@Setter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PostImage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Setter(AccessLevel.NONE)
    @Column(name = "image_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "post_id", nullable = false)
    private Post post;

    @Column(name = "storage_key", nullable = false, unique = true, length = 255)
    private String storageKey;

    @JdbcTypeCode(SqlTypes.TINYINT)
    @Column(name = "order_no", nullable = false)
    private Integer orderNo;

    @Builder
    private PostImage(Post post, String storageKey, Integer orderNo) {
        this.post = post;
        this.storageKey = storageKey;
        this.orderNo = orderNo;
    }
}
