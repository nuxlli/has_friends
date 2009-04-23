require "#{File.dirname(__FILE__)}/spec_helper"

# unset models used for testing purposes
Object.unset_class('User')

class User < ActiveRecord::Base
  has_friends
end

describe "has_friends" do
  fixtures :users
  
  describe "methods" do
    it "should respond to has_friends method" do
      User.should respond_to(:has_friends)
    end
    
    it "should respond to be_friends_with method" do
      @vader.should respond_to(:be_friends_with)
    end
    
    it "should respond to friends? method" do
      @vader.should respond_to(:friends?)
    end
    
    it "should respond to accept_friendship_with" do
      @vader.should respond_to(:accept_friendship_with)
    end
    
    it "should respond to remove_friendship_with" do
      @vader.should respond_to(:remove_friendship_with)
    end
  end
  
  describe "user" do
    before(:each) do
      #requesting friendship between @vader and @luke
      @vader.be_friends_with(@luke)
    end
    
    it "should accept a friendship" do
      @luke.accept_friendship_with(@vader)
      
      @luke.reload
      @vader.reload
      
      @vader.friends.should == [@luke]
      @luke.friends.should == [@vader]
      @vader.friends_count.should == 1
      @luke.friends_count.should == 1
    end
    
    it "should reject when user try accept his friendship request" do
      lambda { @vader.accept_friendship_with(@luke) }.should raise_error(YouCanNotAcceptARequestFriendshipError)
      
      @luke.reload
      @vader.reload

      @vader.friends.should == []
      @luke.friends.should == []
      @vader.friends_count.should == 0
      @luke.friends_count.should == 0
    end
    
    it "should remove a friendship" do
      #make @vader and @luke friends
      @luke.be_friends_with(@vader)
      
      @vader.remove_friendship_with(@luke)
      
      @luke.reload
      @vader.reload

      @vader.friends.should == []
      @luke.friends.should == []
      @vader.friends_count.should == 0
      @luke.friends_count.should == 0
    end
  end
  
  describe "friends" do
    before(:each) do
      create_friendship @vader, @luke
      create_friendship @vader, @leia
      create_friendship @luke, @leia
      create_friendship @luke, @yoda
      create_friendship @leia, @han_solo
    end
    
    it "should order vader's friends" do
      # => princess_leia, luke_skywalker
      @vader.friends.all(:order => 'login desc').should == [@leia, @luke]
    end
    
    it "should return luke's friends" do
      @luke.friends.should == [@vader, @leia, @yoda]
    end
    
    it "should return leia's frieds" do
      @leia.friends.should == [@vader, @luke, @han_solo]
    end
    
    it "should return yoda's friends" do
      @yoda.friends.should == [@luke]
    end
    
    it "should return solo's friends" do
      @han_solo.friends.should == [@leia]
    end
    
    it "should increment counter" do
      @vader.reload
      @vader.friends_count.should == 2
    end
    
    it "should decrement counter" do
      friendship = @vader.friendship_for(@luke)
      friendship.destroy
      
      @vader.reload
      @vader.friends_count.should == 1
    end
    
    it "should be @vader" do
      @vader.is?(@vader).should be_true
    end
    
    it "should not be @vader" do
      @vader.is?(@leia).should_not be_true
    end
  end
  
  describe "friendship request" do
    it "should return nil and 'friend is required' status" do
      friendship, status = @vader.be_friends_with(nil)
      
      friendship.should be_nil
      status.should == Friendship::STATUS_FRIEND_IS_REQUIRED
    end
    
    it "should return nil and 'is you' status" do
      friendship, status = @vader.be_friends_with(@vader)
      
      friendship.should be_nil
      status.should == Friendship::STATUS_IS_YOU
    end
    
    it "should return nil and 'already friends status" do
      @vader.be_friends_with(@luke)
      @luke.be_friends_with(@vader)
      friendship, status = @vader.be_friends_with(@luke)
      
      friendship.should be_nil
      status.should == Friendship::STATUS_ALREADY_FRIENDS
    end
    
    it "should return nil and 'already requested' status" do
      @vader.be_friends_with(@luke)
      friendship, status = @vader.be_friends_with(@luke)
      
      friendship.should be_nil
      status.should == Friendship::STATUS_ALREADY_REQUESTED
    end
    
    it "should return friendship and 'accepted friendship' status" do
      @vader.be_friends_with(@luke)
      friendship, status = @luke.be_friends_with(@vader)
      
      friendship.should be_kind_of(Friendship)
      status.should == Friendship::STATUS_FRIENDSHIP_ACCEPTED
      @vader.should be_friends(@luke)
      @luke.should be_friends(@vader)
    end
    
    it "should create friendships" do
      doing {
        doing {
          friendship, status = @vader.be_friends_with(@luke, "Luke, I'm your father!")
        
          @vader.friendships.count.should == 1
          @luke.friendships.count.should == 1
          status.should == Friendship::STATUS_REQUESTED
          friendship.message.body.should == "Luke, I'm your father!"
        
        }.should change(Friendship, :count).by(2)
      }.should change(FriendshipMessage, :count).by(1)
    end
  end
  
  describe FriendshipMessage do
    it "should require a body" do
      @message = FriendshipMessage.new
      @message.should_not be_valid
      @message.errors[:body].should == "can't be blank"
    end
  end
  
  describe Friendship do
    describe "structure" do
      it "should belong_to user" do
        @friendship = Friendship.new(:user => @vader)
        @friendship.user.should == @vader
      end
      
      it "should_belong_to friend" do
        @friendship = Friendship.new(:friend => @luke)
        @friendship.friend.should == @luke
      end
      
      it "should belong_to message" do
        @message = FriendshipMessage.new :body => "Luke, I'm your father!"
        @friendship = Friendship.new(:message => @vader_message_for_luke)
        @friendship.message == @vader_message_for_luke
      end
    end
    
    it "should be pending status" do
      @friendship = Friendship.new(:status => 'pending')
      @friendship.should be_pending
    end
    
    it "should be accepted status" do
      @friendship = Friendship.new(:status => 'accepted')
      @friendship.should be_accepted
    end
    
    it "should be requested status" do
      @friendship = Friendship.new(:status => 'requested')
      @friendship.should be_requested
    end
  end
  
  describe "pagination" do
    before(:each) do
      pending unless Object.const_defined?('Paginate')
      
      create_friendship @vader, @luke
      create_friendship @vader, @leia
      create_friendship @vader, @han_solo
    end
    
    it "should paginate friends" do
      @vader.friends.paginate(:limit => 1).to_a.should == [@luke, @leia]
    end
  end
  
  private
    def create_friendship(user1, user2)
      user1.be_friends_with(user2)
      user2.be_friends_with(user1)
    end
end