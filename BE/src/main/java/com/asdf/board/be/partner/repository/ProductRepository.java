package com.asdf.board.be.partner.repository;

import com.asdf.board.be.partner.entity.Product;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductRepository extends JpaRepository<Product, Long> {

    List<Product> findByCategoryAndDisplayFromLessThanEqualAndDisplayToGreaterThanEqualOrderByIdAsc(
            Product.Category category, LocalDate from, LocalDate to);

    String VISIBLE = "p.displayFrom <= :today and p.displayTo >= :today";

    @Query(value = "select p from Product p join fetch p.partner where " + VISIBLE + " order by p.id desc",
            countQuery = "select count(p) from Product p where " + VISIBLE)
    Page<Product> visible(@Param("today") java.time.LocalDate today, Pageable pageable);

    @Query(value = "select p from Product p join fetch p.partner where p.category = :category and " + VISIBLE + " order by p.id desc",
            countQuery = "select count(p) from Product p where p.category = :category and " + VISIBLE)
    Page<Product> visibleByCategory(@Param("category") Product.Category category,
                                    @Param("today") java.time.LocalDate today, Pageable pageable);

    @Query("select p from Product p join fetch p.partner where p.id = :id")
    Optional<Product> findWithPartner(@Param("id") Long id);
}
