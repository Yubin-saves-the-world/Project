package com.asdf.board.be.body.integration;

import com.asdf.board.be.body.entity.Photo;
import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PhotoRepository extends JpaRepository<Photo, Long> {
  List<Photo> findByUserIdAndDeletedAtIsNullOrderByIdDesc(Long userId);
}
