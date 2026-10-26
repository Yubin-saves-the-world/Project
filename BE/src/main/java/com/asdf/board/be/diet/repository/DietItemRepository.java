package com.asdf.board.be.diet.repository;

import com.asdf.board.be.diet.entity.DietItem;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DietItemRepository extends JpaRepository<DietItem, Long> {

    @Query("select i from DietItem i left join fetch i.product where i.meal.id in :mealIds order by i.id")
    List<DietItem> findWithProduct(@Param("mealIds") Collection<Long> mealIds);
}
