package com.asdf.board.be.body.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.body.entity.Photo;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PhotoRepository extends JpaRepository<Photo, Long> {

    Optional<Photo> findByIdAndUserId(Long id, Long userId);

    long countByUserId(Long userId);

    Page<Photo> findByUserId(Long userId, Pageable pageable);

    Page<Photo> findByUserIdAndType(Long userId, Photo.Type type, Pageable pageable);

    List<Photo> findByUserIdAndType(Long userId, Photo.Type type);

    List<Photo> findByUserId(Long userId);

    List<Photo> findByTypeAndExpiresAtBefore(Photo.Type type, LocalDateTime time);

    @BulkWrite
    @Query("delete from Photo p where p.id = :id")
    void deleteRow(@Param("id") Long id);
}
