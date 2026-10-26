package com.asdf.board.be.diet.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.diet.entity.DietPlan;
import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DietPlanRepository extends JpaRepository<DietPlan, Long> {

    Optional<DietPlan> findByIdAndUserId(Long id, Long userId);

    Optional<DietPlan> findByUserIdAndPlanDate(Long userId, LocalDate date);

    List<DietPlan> findByUserIdAndPlanDateGreaterThanEqualOrderByPlanDateAsc(Long userId, LocalDate from);

    @BulkWrite
    @Query("delete from DietItem i where i.meal.id in (select m.id from DietMeal m where m.plan.id in :planIds)")
    void deleteItems(@Param("planIds") Collection<Long> planIds);

    @BulkWrite
    @Query("delete from DietMeal m where m.plan.id in :planIds")
    void deleteMeals(@Param("planIds") Collection<Long> planIds);

    @BulkWrite
    @Query("delete from DietPlan p where p.id in :planIds")
    void deletePlans(@Param("planIds") Collection<Long> planIds);
}
