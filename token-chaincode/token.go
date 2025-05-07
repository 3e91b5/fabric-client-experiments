package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// Balance 기록
type Account struct {
	Balance int `json:"balance"`
}

type TokenContract struct {
	contractapi.Contract
}

// 최초 100개 주소에 1000 토큰씩 지급
func (t *TokenContract) InitLedger_random_100_account(ctx contractapi.TransactionContextInterface) error {
	rand.Seed(time.Now().UnixNano())
	for i := 0; i < 100; i++ {
		addr := fmt.Sprintf("addr%03d", i)
		acc := &Account{Balance: 1000}
		data, _ := json.Marshal(acc)
		if err := ctx.GetStub().PutState(addr, data); err != nil {
			return err
		}
	}
	return nil
}

// 최초 100개 주소에 1000 토큰씩 지급
func (t *TokenContract) InitLedger_master_account(ctx contractapi.TransactionContextInterface) error {

	for i := 0; i < 100; i++ {
		addr := fmt.Sprintf("addr%03d", i)
		acc := &Account{Balance: 1000}
		data, _ := json.Marshal(acc)
		if err := ctx.GetStub().PutState(addr, data); err != nil {
			return err
		}
	}
	return nil
}

// 잔액 조회
func (t *TokenContract) BalanceOf(ctx contractapi.TransactionContextInterface, addr string) (int, error) {
	data, err := ctx.GetStub().GetState(addr)
	if err != nil || data == nil {
		return 0, fmt.Errorf("account not found")
	}
	var acc Account
	_ = json.Unmarshal(data, &acc)
	return acc.Balance, nil
}

// 전송
func (t *TokenContract) Transfer(ctx contractapi.TransactionContextInterface, from, to string, amt int) error {
	if amt <= 0 {
		return fmt.Errorf("amount must be positive")
	}

	// 읽기
	fbytes, _ := ctx.GetStub().GetState(from)
	tbytes, _ := ctx.GetStub().GetState(to)
	if fbytes == nil || tbytes == nil {
		return fmt.Errorf("account missing")
	}
	var fAcc, tAcc Account
	_ = json.Unmarshal(fbytes, &fAcc)
	_ = json.Unmarshal(tbytes, &tAcc)

	if fAcc.Balance < amt {
		return fmt.Errorf("insufficient funds")
	}

	// 쓰기
	fAcc.Balance -= amt
	tAcc.Balance += amt
	fNew, _ := json.Marshal(fAcc)
	tNew, _ := json.Marshal(tAcc)
	if err := ctx.GetStub().PutState(from, fNew); err != nil {
		return err
	}
	return ctx.GetStub().PutState(to, tNew)
}

func main() {
	cc, _ := contractapi.NewChaincode(new(TokenContract))
	cc.Start()
}

func (t *TokenContract) ResetLedger(ctx contractapi.TransactionContextInterface) error {
	// 모든 키 삭제
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return err
	}
	defer resultsIterator.Close()
	for resultsIterator.HasNext() {
		kv, _ := resultsIterator.Next()
		if err := ctx.GetStub().DelState(kv.Key); err != nil {
			return err
		}
	}
	// 초기 balance 재투입
	return t.InitLedger_random_100_account(ctx)
}
