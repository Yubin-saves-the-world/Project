package com.asdf.board.be.community.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.community.entity.PostLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostLikeRepository extends JpaRepository<PostLike, PostLike.Key> {

    boolean existsByIdPostIdAndIdUserId(Long postId, Long userId);

    int countByIdPostId(Long postId);

    @BulkWrite
    @Query("delete from PostLike l where l.id.postId = :postId and l.id.userId = :userId")
    void deleteOne(@Param("postId") Long postId, @Param("userId") Long userId);

    @BulkWrite
    @Query("delete from PostLike l where l.id.postId = :postId")
    void deleteAllOfPost(@Param("postId") Long postId);
}
