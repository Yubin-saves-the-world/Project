package com.asdf.board.be.community.repository;

import com.asdf.board.be.community.entity.PostImage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PostImageRepository extends JpaRepository<PostImage, Long> {

    List<PostImage> findByPostIdOrderByOrderNoAsc(Long postId);

    void deleteByPostIdAndIdIn(Long postId, List<Long> ids);
}
