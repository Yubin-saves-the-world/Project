package com.asdf.board.be.community.repository;

import com.asdf.board.be.global.persistence.BulkWrite;
import com.asdf.board.be.community.entity.PostImage;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostImageRepository extends JpaRepository<PostImage, Long> {

    List<PostImage> findByPostIdOrderByOrderNoAsc(Long postId);

    List<PostImage> findByPostIdInOrderByPostIdAscOrderNoAsc(Collection<Long> postIds);

    @Query("select i.storageKey from PostImage i where i.post.user.id = :userId")
    List<String> storageKeysOfUser(@Param("userId") Long userId);

    @BulkWrite
    @Query("delete from PostImage i where i.post.id = :postId")
    void deleteAllOfPost(@Param("postId") Long postId);

    @BulkWrite
    @Query("delete from PostImage i where i.id in :ids")
    void deleteByIds(@Param("ids") Collection<Long> ids);
}
