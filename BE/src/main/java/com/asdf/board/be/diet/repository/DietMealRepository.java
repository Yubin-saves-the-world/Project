package com.asdf.board.be.diet.repository;

import com.asdf.board.be.diet.entity.DietMeal;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DietMealRepository extends JpaRepository<DietMeal, Long> {

    List<DietMeal> findByPlanIdIn(Collection<Long> planIds);
}
