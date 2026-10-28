package com.asdf.board.be.community.repository;

import com.asdf.board.be.community.entity.Post;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostRepository extends JpaRepository<Post, Long> {

    @Query("SELECT p FROM Post p WHERE p.hiddenAt IS NULL AND (:category IS NULL OR p.category = :category) ORDER BY p.isPinned DESC, p.createdAt DESC")
    Page<Post> findVisible(@Param("category") Post.Category category, Pageable pageable);
}
